#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

NIM_RUN_MODE="${NIM_RUN_MODE:-api}"
cd "${ROOT_DIR}"

if [[ "${NIM_RUN_MODE}" == "local_nim" ]]; then
  docker compose -f docker-compose.yaml -f docker-compose-nim-local.yaml down --remove-orphans || true
else
  docker compose -f docker-compose.yaml down --remove-orphans || true
fi

echo "Stopped"
