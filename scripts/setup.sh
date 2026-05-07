#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_EXAMPLE="${ROOT_DIR}/.env.example"
RUNTIME_DIR="${ROOT_DIR}/.runtime"

log() {
  printf "[RETAIL][SETUP] %s\n" "$1"
}

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${ENV_EXAMPLE}" ]]; then
    cp "${ENV_EXAMPLE}" "${ENV_FILE}"
    log "Created .env from .env.example"
  else
    echo "Missing ${ENV_FILE} and ${ENV_EXAMPLE}" >&2
    exit 1
  fi
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker is required" >&2
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  :
elif command -v docker-compose >/dev/null 2>&1; then
  :
else
  echo "docker compose plugin (or docker-compose) is required" >&2
  exit 1
fi

# shellcheck disable=SC1090
source <(sed 's/\r$//' "${ENV_FILE}")

NIM_RUN_MODE="${NIM_RUN_MODE:-api}"
if [[ "${NIM_RUN_MODE}" != "api" && "${NIM_RUN_MODE}" != "local_nim" ]]; then
  echo "NIM_RUN_MODE must be api or local_nim" >&2
  exit 1
fi

if [[ "${NIM_RUN_MODE}" == "api" ]]; then
  if [[ -z "${NVIDIA_API_KEY:-}" && -z "${NGC_API_KEY:-}" ]]; then
    echo "Set NVIDIA_API_KEY (or NGC_API_KEY) in .env" >&2
    exit 1
  fi
else
  mkdir -p "${LOCAL_NIM_CACHE:-$HOME/.cache/nim}"
  chmod a+w "${LOCAL_NIM_CACHE:-$HOME/.cache/nim}" || true
fi

mkdir -p "${RUNTIME_DIR}"
log "Setup complete (mode=${NIM_RUN_MODE})"
