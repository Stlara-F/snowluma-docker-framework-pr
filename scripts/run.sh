#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE="${IMAGE:-snowluma-docker-framework:latest}"
NAME="${NAME:-snowluma}"
SNOWLUMA_WEBUI_PORT="${SNOWLUMA_WEBUI_PORT:-5099}"
SNOWLUMA_WEBUI_HOST_PORT="${SNOWLUMA_WEBUI_HOST_PORT:-5099}"

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  IMAGE="${IMAGE}" "${SCRIPT_DIR}/build-image.sh"
fi

if docker ps -a --format '{{.Names}}' | grep -qx "${NAME}"; then
  if [ "${RECREATE:-0}" = "1" ]; then
    docker rm -f "${NAME}" >/dev/null
  else
    echo "Container ${NAME} already exists. Set RECREATE=1 to replace it."
    exit 1
  fi
fi

docker volume create snowluma-data >/dev/null
docker volume create snowluma-qq-config >/dev/null
docker volume create snowluma-qq-data >/dev/null

docker run -d \
  --name "${NAME}" \
  --restart unless-stopped \
  --shm-size=1g \
  --cap-add=SYS_PTRACE \
  --security-opt seccomp=unconfined \
  -e VNC_PASSWD="${VNC_PASSWD:-vncpasswd}" \
  -e SNOWLUMA_UID="${SNOWLUMA_UID:-1000}" \
  -e SNOWLUMA_GID="${SNOWLUMA_GID:-1000}" \
  -e SNOWLUMA_WEBUI_PORT="${SNOWLUMA_WEBUI_PORT}" \
  -e SNOWLUMA_LOG_LEVEL="${SNOWLUMA_LOG_LEVEL:-info}" \
  -p "${VNC_PORT:-5900}:5900" \
  -p "${NOVNC_PORT:-6081}:6081" \
  -p "${SNOWLUMA_WEBUI_HOST_PORT}:${SNOWLUMA_WEBUI_PORT}" \
  -p "${ONEBOT_HTTP_PORT:-3000}:3000" \
  -p "${ONEBOT_WS_PORT:-3001}:3001" \
  -v snowluma-data:/app/snowluma-data \
  -v snowluma-qq-config:/app/.config \
  -v snowluma-qq-data:/app/.local/share \
  "${IMAGE}"

echo "Started ${NAME}"
echo "noVNC: http://127.0.0.1:${NOVNC_PORT:-6081}/"
echo "WebUI: http://127.0.0.1:${SNOWLUMA_WEBUI_HOST_PORT}/"
echo "Logs:  docker logs -f ${NAME}"
