#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_SOURCE_DIR="$(cd "${FRAMEWORK_DIR}/../.." && pwd)"

SNOWLUMA_SOURCE_DIR="${SNOWLUMA_SOURCE_DIR:-${DEFAULT_SOURCE_DIR}}"
SNOWLUMA_TARGET="${SNOWLUMA_TARGET:-linux-x64}"
ARTIFACT_PATH="${ARTIFACT_PATH:-${FRAMEWORK_DIR}/SnowLuma.Framework.tar.gz}"

if [ "${SNOWLUMA_TARGET}" != "linux-x64" ]; then
  echo "Only SNOWLUMA_TARGET=linux-x64 is currently supported by this Docker framework."
  echo "Missing SnowLuma hook native binaries for: ${SNOWLUMA_TARGET}"
  exit 1
fi

if [ ! -f "${SNOWLUMA_SOURCE_DIR}/package.json" ]; then
  echo "SnowLuma source directory is invalid: ${SNOWLUMA_SOURCE_DIR}"
  exit 1
fi

if ! command -v pnpm >/dev/null 2>&1; then
  echo "pnpm is required to package SnowLuma."
  exit 1
fi

echo "Packaging SnowLuma from ${SNOWLUMA_SOURCE_DIR}"

if [ "${SKIP_PNPM_INSTALL:-0}" != "1" ]; then
  (cd "${SNOWLUMA_SOURCE_DIR}" && CI=true pnpm install --frozen-lockfile)
fi

(cd "${SNOWLUMA_SOURCE_DIR}" && SNOWLUMA_TARGET="${SNOWLUMA_TARGET}" pnpm build:all)

DIST_DIR="${SNOWLUMA_SOURCE_DIR}/dist"
NATIVE_DIR="${DIST_DIR}/native"

mkdir -p "${NATIVE_DIR}"

for ext in node so; do
  src="${SNOWLUMA_SOURCE_DIR}/native/snowluma-${SNOWLUMA_TARGET}.${ext}"
  if [ -f "${src}" ]; then
    cp "${src}" "${NATIVE_DIR}/"
  fi
done

required_files=(
  "${DIST_DIR}/index.mjs"
  "${DIST_DIR}/package.json"
  "${DIST_DIR}/client/index.html"
  "${NATIVE_DIR}/snowluma-linux-x64.node"
  "${NATIVE_DIR}/snowluma-linux-x64.so"
  "${NATIVE_DIR}/websocket-linux-x64.node"
)

for file in "${required_files[@]}"; do
  if [ ! -f "${file}" ]; then
    echo "Required SnowLuma release file is missing: ${file}"
    exit 1
  fi
done

tar -C "${DIST_DIR}" -czf "${ARTIFACT_PATH}" .

echo "Created ${ARTIFACT_PATH}"
