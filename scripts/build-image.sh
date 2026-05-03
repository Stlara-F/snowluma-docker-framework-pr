#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

IMAGE="${IMAGE:-snowluma-docker-framework:latest}"
PLATFORM="${PLATFORM:-linux/amd64}"

"${SCRIPT_DIR}/prepare-artifact.sh"

docker buildx build \
  --load \
  --platform "${PLATFORM}" \
  --tag "${IMAGE}" \
  --file "${FRAMEWORK_DIR}/Dockerfile" \
  "${FRAMEWORK_DIR}"

echo "Built ${IMAGE} for ${PLATFORM}"
