#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing .env. Run scripts/setup.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

NIM_RUN_MODE="${NIM_RUN_MODE:-api}"
API_KEY="${NVIDIA_API_KEY:-${NGC_API_KEY:-}}"

cd "${ROOT_DIR}"

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

  docker compose -f docker-compose.yaml up -d --build
else
  export CONFIG_OVERRIDE="${CONFIG_OVERRIDE:-}"
  export LOCAL_NIM_CACHE="${LOCAL_NIM_CACHE:-$HOME/.cache/nim}"
  export NGC_API_KEY="${NGC_API_KEY:-$API_KEY}"

  if [[ -z "${NGC_API_KEY}" ]]; then
    echo "NGC_API_KEY is required for local_nim mode" >&2
    exit 1
  fi

  docker compose -f docker-compose-nim-local.yaml up -d
  docker compose -f docker-compose.yaml up -d --build
fi

echo "Started. Open http://localhost:3000"
