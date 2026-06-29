#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
IMAGE="${IMAGE:-snowluma-docker-framework:latest}"
PUSH="${PUSH:-0}"
SNOWLUMA_REPO="${SNOWLUMA_REPO:-SnowLuma/SnowLuma}"
SNOWLUMA_TAG="${SNOWLUMA_TAG:-}"
SNOWLUMA_ARTIFACT_SUFFIX="${SNOWLUMA_ARTIFACT_SUFFIX:--vnc}"
ARTIFACT="${FRAMEWORK_DIR}/SnowLuma.Framework.tar.gz"
if [ "${PUSH}" = "1" ] || [ "${PUSH}" = "true" ]; then PLATFORM="${PLATFORM:-linux/amd64}"; OUTPUT="${OUTPUT:---push}"; else PLATFORM="${PLATFORM:-linux/amd64}"; OUTPUT="${OUTPUT:---load}"; fi
case ",${PLATFORM}," in *,*,*) echo "Single platform only." >&2; exit 1 ;; esac
case "${PLATFORM}" in linux/amd64) asset_arch="linux-x64" ;; linux/arm64) asset_arch="linux-arm64" ;; *) echo "Unsupported PLATFORM" >&2; exit 1 ;; esac
if [ -n "${SNOWLUMA_TAG}" ]; then
  if ! command -v gh >/dev/null 2>&1; then echo "gh CLI not found." >&2; exit 1; fi
  asset="SnowLuma-${SNOWLUMA_TAG}-${asset_arch}${SNOWLUMA_ARTIFACT_SUFFIX}-lite.tar.gz"
  echo "Fetching ${asset}"; gh release download "${SNOWLUMA_TAG}" --repo "${SNOWLUMA_REPO}" --pattern "${asset}" --output "${ARTIFACT}" --clobber
elif [ ! -f "${ARTIFACT}" ]; then echo "Missing ${ARTIFACT}." >&2; exit 1; fi
docker buildx build --platform "${PLATFORM}" --tag "${IMAGE}" --file "${FRAMEWORK_DIR}/Dockerfile" ${OUTPUT} "${FRAMEWORK_DIR}"
echo "Built ${IMAGE}"
