#!/usr/bin/env bash
# Resolve SnowLuma.Framework.tar.gz for Docker build context.
#
# Priority:
#   1. SnowLuma.Framework.<linux-x64|linux-arm64>.tar.gz in repo root
#   2. SnowLuma.Framework.tar.gz in repo root (amd64 alias only)
#   3. gh release download when SNOWLUMA_TAG is set
#
# Examples:
#   PLATFORM=linux/amd64 ./scripts/resolve-framework-tarball.sh
#   PLATFORM=linux/arm64 SNOWLUMA_TAG=v1.8.5 ./scripts/resolve-framework-tarball.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

PLATFORM="${PLATFORM:-linux/amd64}"
ARTIFACT="${ARTIFACT:-${FRAMEWORK_DIR}/SnowLuma.Framework.tar.gz}"
SNOWLUMA_REPO="${SNOWLUMA_REPO:-SnowLuma/SnowLuma}"
SNOWLUMA_TAG="${SNOWLUMA_TAG:-}"
SNOWLUMA_ARTIFACT_SUFFIX="${SNOWLUMA_ARTIFACT_SUFFIX:--vnc}"

case "${PLATFORM}" in
  linux/amd64) asset_arch="linux-x64" ;;
  linux/arm64) asset_arch="linux-arm64" ;;
  *)
    echo "Unsupported PLATFORM: ${PLATFORM}" >&2
    exit 1
    ;;
esac

per_arch="${FRAMEWORK_DIR}/SnowLuma.Framework.${asset_arch}.tar.gz"
default_tarball="${FRAMEWORK_DIR}/SnowLuma.Framework.tar.gz"

install_repo_tarball() {
  local source="$1"
  if [ "${source}" = "${ARTIFACT}" ]; then
    echo "Using ${source}"
    return 0
  fi
  cp "${source}" "${ARTIFACT}"
  echo "Using ${source} -> ${ARTIFACT}"
}

if [ -f "${per_arch}" ]; then
  install_repo_tarball "${per_arch}"
  exit 0
fi

if [ "${asset_arch}" = "linux-x64" ] && [ -f "${default_tarball}" ]; then
  install_repo_tarball "${default_tarball}"
  exit 0
fi

if [ -n "${SNOWLUMA_TAG}" ]; then
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found. Install from https://cli.github.com/ or commit framework tarballs to the repo root." >&2
    exit 1
  fi
  # Check the release actually exists before attempting download
  if ! gh release view "${SNOWLUMA_TAG}" --repo "${SNOWLUMA_REPO}" >/dev/null 2>&1; then
    echo "Warning: release '${SNOWLUMA_TAG}' not found in ${SNOWLUMA_REPO}." >&2
    echo "Falling back to checked-in tarballs." >&2
  else
    asset="SnowLuma-${SNOWLUMA_TAG}-${asset_arch}${SNOWLUMA_ARTIFACT_SUFFIX}-lite.tar.gz"
    echo "Fetching ${asset} from ${SNOWLUMA_REPO}@${SNOWLUMA_TAG}"
    gh release download "${SNOWLUMA_TAG}" \
      --repo "${SNOWLUMA_REPO}" \
      --pattern "${asset}" \
      --output "${ARTIFACT}" \
      --clobber
    exit 0
  fi
fi

echo "No framework tarball available for ${PLATFORM}." >&2
echo "Commit one of these at the repo root, or set SNOWLUMA_TAG to download a release:" >&2
echo "  - ${per_arch}" >&2
if [ "${asset_arch}" = "linux-x64" ]; then
  echo "  - ${default_tarball}" >&2
fi
echo "Run ./scripts/sync-dev-framework.sh to refresh dev builds from SnowLuma/SnowLuma." >&2
exit 1
