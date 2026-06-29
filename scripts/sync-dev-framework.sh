#!/usr/bin/env bash
# Download SnowLuma dev-branch Dev Build lite tarballs into the repo root.
#
# Required environment variables (provided by the workflow):
#   SOURCE_REPO   - source repository (e.g., Stlara-F/SnowLuma)
#   TARGET_TAG    - tag used in artifact names (e.g., dev)
#   HEAD_SHA      - commit SHA to match artifacts
#   RUN_ID        - workflow run ID of the Dev Build
#   PLATFORMS     - comma-separated list (linux-x64,linux-arm64)
#   LOCK_FILE     - path to lock file (optional, used for consistency only)
#   GH_TOKEN      - GitHub token for gh CLI
#
# Example:
#   SOURCE_REPO=Stlara-F/SnowLuma TARGET_TAG=dev HEAD_SHA=abc123 RUN_ID=12345678 \
#   PLATFORMS=linux-x64,linux-arm64 LOCK_FILE=.github/snowluma-sync-abc.json \
#   ./scripts/sync-dev-framework.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SOURCE_REPO="${SOURCE_REPO:-Stlara-F/SnowLuma}"
TARGET_TAG="${TARGET_TAG:-dev}"
ARTIFACT_SUFFIX="${ARTIFACT_SUFFIX:--vnc}"
PLATFORMS="${PLATFORMS:-linux-x64,linux-arm64}"
HEAD_SHA="${HEAD_SHA:-}"
RUN_ID="${RUN_ID:-}"
LOCK_FILE="${LOCK_FILE:-}"

if [ -z "${HEAD_SHA}" ] || [ -z "${RUN_ID}" ]; then
  echo "ERROR: HEAD_SHA and RUN_ID are required." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI not found." >&2
  exit 1
fi

# Output path for a given platform
framework_output_for_platform() {
  printf '%s/SnowLuma.Framework.%s.tar.gz' "${FRAMEWORK_DIR}" "$1"
}

# Find the inner tarball (prefer -lite) inside the downloaded artifact directory
find_inner_tarball() {
  local base_dir="$1"
  local platform="$2"
  local lite_name full_name found

  # Prefer suffixed variant (e.g. -vnc), fall back to regular
  lite_name="SnowLuma-${TARGET_TAG}-${platform}${ARTIFACT_SUFFIX}-lite.tar.gz"
  full_name="SnowLuma-${TARGET_TAG}-${platform}${ARTIFACT_SUFFIX}.tar.gz"
  lite_fallback="SnowLuma-${TARGET_TAG}-${platform}-lite.tar.gz"
  full_fallback="SnowLuma-${TARGET_TAG}-${platform}.tar.gz"

  # Try suffixed variant first (e.g. -vnc)
  if [ -f "${base_dir}/${lite_name}" ]; then printf '%s\n' "${base_dir}/${lite_name}"; return 0; fi
  if [ -f "${base_dir}/${full_name}" ]; then printf '%s\n' "${base_dir}/${full_name}"; return 0; fi

  # Try zip
  local zip_file="$(find "${base_dir}" -maxdepth 1 -type f -name '*.zip' | head -n 1)"
  if [ -n "${zip_file}" ]; then
    local extract_dir="${base_dir}/extracted"; mkdir -p "${extract_dir}"
    unzip -qo "${zip_file}" -d "${extract_dir}"
    found="$(find "${extract_dir}" -type f -name "${lite_name}" | head -n 1)"
    if [ -n "${found}" ]; then printf '%s\n' "${found}"; return 0; fi
    found="$(find "${extract_dir}" -type f -name "${full_name}" | head -n 1)"
    if [ -n "${found}" ]; then printf '%s\n' "${found}"; return 0; fi
  fi

  # Recursive search suffixed
  found="$(find "${base_dir}" -type f -name "${lite_name}" | head -n 1)"
  if [ -n "${found}" ]; then printf '%s\n' "${found}"; return 0; fi
  found="$(find "${base_dir}" -type f -name "${full_name}" | head -n 1)"
  if [ -n "${found}" ]; then printf '%s\n' "${found}"; return 0; fi

  # Fallback to regular (no suffix)
  if [ -f "${base_dir}/${lite_fallback}" ]; then printf '%s\n' "${base_dir}/${lite_fallback}"; return 0; fi
  if [ -f "${base_dir}/${full_fallback}" ]; then printf '%s\n' "${base_dir}/${full_fallback}"; return 0; fi
  found="$(find "${extract_dir}" -type f -name "${lite_fallback}" 2>/dev/null | head -n 1)"
  if [ -n "${found}" ]; then printf '%s\n' "${found}"; return 0; fi
  found="$(find "${extract_dir}" -type f -name "${full_fallback}" 2>/dev/null | head -n 1)"
  if [ -n "${found}" ]; then printf '%s\n' "${found}"; return 0; fi
  found="$(find "${base_dir}" -type f -name "${lite_fallback}" | head -n 1)"
  if [ -n "${found}" ]; then printf '%s\n' "${found}"; return 0; fi
  found="$(find "${base_dir}" -type f -name "${full_fallback}" | head -n 1)"
  if [ -n "${found}" ]; then printf '%s\n' "${found}"; return 0; fi

  return 1
}

sync_platform() {
  local platform="$1"
  local output artifact_name download_dir inner_tarball

  case "${platform}" in
    linux-x64|linux-arm64) ;;
    *)
      echo "Unsupported platform: ${platform}" >&2
      return 1
      ;;
  esac

  output="$(framework_output_for_platform "${platform}")"
  artifact_name="SnowLuma-${TARGET_TAG}-${HEAD_SHA}-${platform}"
  download_dir="$(mktemp -d)"

  echo "Downloading artifact ${artifact_name} from run ${RUN_ID} (${SOURCE_REPO})"
  gh run download "${RUN_ID}" \
    --repo "${SOURCE_REPO}" \
    --name "${artifact_name}" \
    --dir "${download_dir}"

  if ! inner_tarball="$(find_inner_tarball "${download_dir}" "${platform}")"; then
    echo "ERROR: Could not find inner tarball for ${platform} under ${download_dir}" >&2
    find "${download_dir}" -type f >&2 || true
    rm -rf "${download_dir}"
    return 1
  fi

  if [ ! -f "${inner_tarball}" ]; then
    echo "ERROR: Inner tarball missing: ${inner_tarball}" >&2
    rm -rf "${download_dir}"
    return 1
  fi

  # Copy the inner tarball to the final output
  cp "${inner_tarball}" "${output}"
  rm -rf "${download_dir}"
  echo "Wrote ${output}"
}

IFS=',' read -r -a PLATFORM_LIST <<< "${PLATFORMS}"
for raw_platform in "${PLATFORM_LIST[@]}"; do
  platform="$(echo "${raw_platform}" | xargs)"
  [ -n "${platform}" ] || continue
  sync_platform "${platform}"
done

# Create a generic SnowLuma.Framework.tar.gz from linux-x64 (if available)
x64_output="$(framework_output_for_platform linux-x64)"
default_output="${FRAMEWORK_DIR}/SnowLuma.Framework.tar.gz"
if [ -f "${x64_output}" ]; then
  cp "${x64_output}" "${default_output}"
  echo "Wrote ${default_output} (linux-x64 alias)"
fi

echo "Sync completed successfully."
