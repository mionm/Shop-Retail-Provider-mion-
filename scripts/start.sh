#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
RUNTIME_DIR="${ROOT_DIR}/.runtime"
PORTS_ENV_FILE="${RUNTIME_DIR}/ports.env"
MAIN_OVERRIDE_FILE="${RUNTIME_DIR}/ports.override.yml"
NIM_OVERRIDE_FILE="${RUNTIME_DIR}/ports.nim.override.yml"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing .env. Run scripts/setup.sh first." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

COMPOSE_CMD=()
if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "docker compose plugin (or docker-compose) is required" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
  echo "python3 (or python) is required for automatic free-port allocation." >&2
  exit 1
fi

PYTHON_BIN="python3"
if ! command -v python3 >/dev/null 2>&1; then
  PYTHON_BIN="python"
fi

# shellcheck disable=SC1090
source <(sed 's/\r$//' "${ENV_FILE}")

NIM_RUN_MODE="${NIM_RUN_MODE:-api}"
API_KEY="${NVIDIA_API_KEY:-${NGC_API_KEY:-}}"

cd "${ROOT_DIR}"
mkdir -p "${RUNTIME_DIR}"

find_free_port() {
  local start_port="$1"
  local max_tries="${2:-200}"
  "${PYTHON_BIN}" - "$start_port" "$max_tries" <<'PY'
import socket
import sys

start = int(sys.argv[1])
tries = int(sys.argv[2])

for p in range(start, start + tries):
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    try:
        s.bind(("0.0.0.0", p))
        s.close()
        print(p)
        raise SystemExit(0)
    except OSError:
        s.close()

raise SystemExit(1)
PY
}

port_ui="$(find_free_port "${PORT_UI:-3000}")"
port_chain="$(find_free_port "${PORT_CHAIN:-8009}")"
port_catalog="$(find_free_port "${PORT_CATALOG:-8010}")"
port_memory="$(find_free_port "${PORT_MEMORY:-8011}")"
port_rails="$(find_free_port "${PORT_RAILS:-8012}")"
port_etcd="$(find_free_port "${PORT_ETCD:-2379}")"
port_minio_api="$(find_free_port "${PORT_MINIO_API:-9000}")"
port_minio_console="$(find_free_port "${PORT_MINIO_CONSOLE:-9001}")"
port_milvus="$(find_free_port "${PORT_MILVUS:-19530}")"
port_milvus_metrics="$(find_free_port "${PORT_MILVUS_METRICS:-9091}")"

cat > "${PORTS_ENV_FILE}" <<EOF
PORT_UI=${port_ui}
PORT_CHAIN=${port_chain}
PORT_CATALOG=${port_catalog}
PORT_MEMORY=${port_memory}
PORT_RAILS=${port_rails}
PORT_ETCD=${port_etcd}
PORT_MINIO_API=${port_minio_api}
PORT_MINIO_CONSOLE=${port_minio_console}
PORT_MILVUS=${port_milvus}
PORT_MILVUS_METRICS=${port_milvus_metrics}
EOF

cat > "${MAIN_OVERRIDE_FILE}" <<EOF
services:
  chain-server:
    ports:
      - "${port_chain}:8009"
  catalog-retriever:
    ports:
      - "${port_catalog}:8010"
  memory-retriever:
    ports:
      - "${port_memory}:8011"
  rails:
    ports:
      - "${port_rails}:8012"
  etcd:
    ports:
      - "${port_etcd}:2379"
  minio:
    ports:
      - "${port_minio_api}:9000"
      - "${port_minio_console}:9001"
  milvus:
    ports:
      - "${port_milvus}:19530"
      - "${port_milvus_metrics}:9091"
  nginx:
    ports:
      - "${port_ui}:80"
EOF

if [[ "${NIM_RUN_MODE}" == "api" ]]; then
  if [[ -z "${API_KEY}" ]]; then
    echo "NVIDIA_API_KEY (or NGC_API_KEY) is required for api mode" >&2
    exit 1
  fi

  export CONFIG_OVERRIDE="${CONFIG_OVERRIDE:-config-build.yaml}"
  export LLM_API_KEY="${LLM_API_KEY:-$API_KEY}"
  export EMBED_API_KEY="${EMBED_API_KEY:-$API_KEY}"
  export RAIL_API_KEY="${RAIL_API_KEY:-$API_KEY}"
  export NGC_API_KEY="${NGC_API_KEY:-$API_KEY}"

  "${COMPOSE_CMD[@]}" -f docker-compose.yaml -f "${MAIN_OVERRIDE_FILE}" up -d --build
else
  export CONFIG_OVERRIDE="${CONFIG_OVERRIDE:-}"
  export LOCAL_NIM_CACHE="${LOCAL_NIM_CACHE:-$HOME/.cache/nim}"
  export NGC_API_KEY="${NGC_API_KEY:-$API_KEY}"
  if command -v id >/dev/null 2>&1; then
    export UID="${UID:-$(id -u)}"
  else
    export UID="${UID:-1000}"
  fi

  if [[ -z "${NGC_API_KEY}" ]]; then
    echo "NGC_API_KEY is required for local_nim mode" >&2
    exit 1
  fi

  nim_nemotron="$(find_free_port "${PORT_NIM_NEMOTRON:-8000}")"
  nim_embedqa="$(find_free_port "${PORT_NIM_EMBEDQA:-8001}")"
  nim_nvclip="$(find_free_port "${PORT_NIM_NVCLIP:-8002}")"
  nim_content="$(find_free_port "${PORT_NIM_CONTENT:-8003}")"
  nim_topic="$(find_free_port "${PORT_NIM_TOPIC:-8004}")"

  cat > "${NIM_OVERRIDE_FILE}" <<EOF
services:
  nemotron:
    ports:
      - "${nim_nemotron}:8000"
  embedqa:
    ports:
      - "${nim_embedqa}:8000"
  nvclip:
    ports:
      - "${nim_nvclip}:8000"
  content:
    ports:
      - "${nim_content}:8000"
  topic_control:
    ports:
      - "${nim_topic}:8000"
EOF

  "${COMPOSE_CMD[@]}" -f docker-compose-nim-local.yaml -f "${NIM_OVERRIDE_FILE}" up -d
  "${COMPOSE_CMD[@]}" -f docker-compose.yaml -f "${MAIN_OVERRIDE_FILE}" up -d --build
fi

echo "Started. Open http://localhost:${port_ui}"
echo "Resolved ports are saved at ${PORTS_ENV_FILE}"
