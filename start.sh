#!/usr/bin/env bash
set -euo pipefail

: "${VNC_PASSWD:=vncpasswd}"
: "${SNOWLUMA_UID:=1000}"
: "${SNOWLUMA_GID:=1000}"
: "${SNOWLUMA_HOME:=/app/snowluma}"
: "${SNOWLUMA_DATA:=/app/snowluma-data}"
: "${SNOWLUMA_WEBUI_PORT:=8080}"
: "${SNOWLUMA_LOG_LEVEL:=info}"

export DISPLAY="${DISPLAY:-:1}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/snowluma-${SNOWLUMA_UID}}"
export SNOWLUMA_HOOK_RUNTIME_DIR="${SNOWLUMA_HOOK_RUNTIME_DIR:-${XDG_RUNTIME_DIR}}"
export SNOWLUMA_LOG_LEVEL

chmod 777 /tmp || true
rm -f /run/dbus/pid /tmp/.X1-lock

mkdir -p \
  /var/run/dbus \
  /root/.vnc \
  "${XDG_RUNTIME_DIR}" \
  "${SNOWLUMA_DATA}/config" \
  /app/.cache \
  /app/.config \
  /app/.local/share

groupmod -o -g "${SNOWLUMA_GID}" snowluma
usermod -o -u "${SNOWLUMA_UID}" -g "${SNOWLUMA_GID}" snowluma

chown -R "${SNOWLUMA_UID}:${SNOWLUMA_GID}" \
  /app \
  /opt/QQ \
  "${XDG_RUNTIME_DIR}"
chmod 700 "${XDG_RUNTIME_DIR}"

node <<'NODE'
const fs = require('fs');
const path = require('path');

const dataDir = process.env.SNOWLUMA_DATA || '/app/snowluma-data';
const configDir = path.join(dataDir, 'config');
const runtimeConfigPath = path.join(configDir, 'runtime.json');
const requestedPort = Number(process.env.SNOWLUMA_WEBUI_PORT || 8080);
const webuiPort = Number.isInteger(requestedPort) && requestedPort > 0 && requestedPort <= 65535
  ? requestedPort
  : 8080;

fs.mkdirSync(configDir, { recursive: true });

let runtimeConfig = {};
try {
  runtimeConfig = JSON.parse(fs.readFileSync(runtimeConfigPath, 'utf8'));
} catch {
  runtimeConfig = {};
}

runtimeConfig.webuiPort = webuiPort;
fs.writeFileSync(runtimeConfigPath, `${JSON.stringify(runtimeConfig, null, 2)}\n`, 'utf8');
NODE

x11vnc -storepasswd "${VNC_PASSWD}" /root/.vnc/passwd >/dev/null

dbus-daemon --config-file=/usr/share/dbus-1/system.conf --print-address &
Xvfb "${DISPLAY}" -screen 0 1920x1080x16 &
fluxbox &
x11vnc -display "${DISPLAY}" -noxrecord -noxfixes -noxdamage -forever -rfbauth /root/.vnc/passwd &
nohup /opt/noVNC/utils/novnc_proxy --vnc localhost:5900 --listen 6081 --file-only >/var/log/novnc.log 2>&1 &

exec supervisord -c /etc/supervisord.conf

