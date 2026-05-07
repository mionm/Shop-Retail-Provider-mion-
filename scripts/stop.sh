#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
RUNTIME_DIR="${ROOT_DIR}/.runtime"
MAIN_OVERRIDE_FILE="${RUNTIME_DIR}/ports.override.yml"
NIM_OVERRIDE_FILE="${RUNTIME_DIR}/ports.nim.override.yml"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source <(sed 's/\r$//' "${ENV_FILE}")
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

NIM_RUN_MODE="${NIM_RUN_MODE:-api}"
cd "${ROOT_DIR}"

if [[ "${NIM_RUN_MODE}" == "local_nim" ]]; then
  "${COMPOSE_CMD[@]}" -f docker-compose.yaml -f "${MAIN_OVERRIDE_FILE}" down --remove-orphans || true
  "${COMPOSE_CMD[@]}" -f docker-compose-nim-local.yaml -f "${NIM_OVERRIDE_FILE}" down --remove-orphans || true
else
  "${COMPOSE_CMD[@]}" -f docker-compose.yaml -f "${MAIN_OVERRIDE_FILE}" down --remove-orphans || true
fi

echo "Stopped"
