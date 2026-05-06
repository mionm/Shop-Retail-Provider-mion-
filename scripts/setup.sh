#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_EXAMPLE="${ROOT_DIR}/.env.example"

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

# shellcheck disable=SC1090
source "${ENV_FILE}"

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

log "Setup complete (mode=${NIM_RUN_MODE})"
