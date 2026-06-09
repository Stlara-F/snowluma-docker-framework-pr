#!/usr/bin/env bash
# Download SnowLuma dev-branch Dev Build lite tarballs into the repo root.
#
# CI-only: expects HEAD_SHA and RUN_ID from environment (resolved by workflow).
#
# Examples (workflow sets these env vars):
#   HEAD_SHA=abc123 RUN_ID=12345678 ./scripts/sync-dev-framework.sh
#   PLATFORMS=linux-x64,linux-arm64 HEAD_SHA=abc123 RUN_ID=12345678 ./scripts/sync-dev-framework.sh
#
# Requires: gh CLI (https://cli.github.com/)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SNOWLUMA_REPO="${SNOWLUMA_REPO:-SnowLuma/SnowLuma}"
PLATFORMS="${PLATFORMS:-linux-x64,linux-arm64}"
HEAD_SHA="${HEAD_SHA:-}"
RUN_ID="${RUN_ID:-}"
LOCK_FILE="${LOCK_FILE:-${FRAMEWORK_DIR}/.github/snowluma-dev-lock.json}"

if [ -z "${HEAD_SHA}" ] || [ -z "${RUN_ID}" ]; then
  echo "HEAD_SHA and RUN_ID are required." >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI not found." >&2
  exit 1
fi

if ! command -v unzip >/dev/null 2>&1; then
  echo "unzip is required." >&2
  exit 1
fi

framework_output_for_platform() {
  printf '%s/SnowLuma.Framework.%s.tar.gz' "${FRAMEWORK_DIR}" "$1"
}

find_lite_tarball() {
  local download_dir="$1"
  local platform="$2"
  local lite_name artifact_name zip_path lite_path

  lite_name="SnowLuma-dev-${platform}-lite.tar.gz"
  artifact_name="SnowLuma-dev-${HEAD_SHA}-${platform}"
  zip_path="${download_dir}/${artifact_name}.zip"

  if [ -f "${download_dir}/${lite_name}" ]; then
    printf '%s\n' "${download_dir}/${lite_name}"
    return 0
  fi
  if [ -f "${zip_path}" ]; then
    unzip -qo "${zip_path}" -d "${download_dir}/extracted"
    printf '%s\n' "${download_dir}/extracted/${lite_name}"
    return 0
  fi

  zip_path="$(find "${download_dir}" -maxdepth 1 -type f -name '*.zip' | head -n 1)"
  if [ -n "${zip_path}" ]; then
    unzip -qo "${zip_path}" -d "${download_dir}/extracted"
    lite_path="$(find "${download_dir}/extracted" -maxdepth 1 -type f -name '*-lite.tar.gz' | head -n 1)"
    if [ -n "${lite_path}" ]; then
      printf '%s\n' "${lite_path}"
      return 0
    fi
  fi

  lite_path="$(find "${download_dir}" -maxdepth 2 -type f -name '*-lite.tar.gz' | head -n 1)"
  if [ -n "${lite_path}" ]; then
    printf '%s\n' "${lite_path}"
    return 0
  fi

  return 1
}

sync_platform() {
  local platform="$1"
  local output artifact_name download_dir lite_path

  case "${platform}" in
    linux-x64|linux-arm64) ;;
    *)
      echo "Unsupported platform: ${platform}" >&2
      return 1
      ;;
  esac

  output="$(framework_output_for_platform "${platform}")"
  artifact_name="SnowLuma-dev-${HEAD_SHA}-${platform}"
  download_dir="$(mktemp -d)"

  echo "Downloading ${artifact_name} from run ${RUN_ID} (${SNOWLUMA_REPO})"
  gh run download "${RUN_ID}" \
    --repo "${SNOWLUMA_REPO}" \
    --name "${artifact_name}" \
    --dir "${download_dir}"

  if ! lite_path="$(find_lite_tarball "${download_dir}" "${platform}")"; then
    echo "Expected lite tarball not found under ${download_dir}" >&2
    find "${download_dir}" -type f >&2 || true
    rm -rf "${download_dir}"
    return 1
  fi

  if [ ! -f "${lite_path}" ]; then
    echo "lite tarball missing: ${lite_path}" >&2
    rm -rf "${download_dir}"
    return 1
  fi

  cp "${lite_path}" "${output}"
  rm -rf "${download_dir}"
  echo "Wrote ${output}"
}

IFS=',' read -r -a PLATFORM_LIST <<< "${PLATFORMS}"
for raw_platform in "${PLATFORM_LIST[@]}"; do
  platform="$(echo "${raw_platform}" | xargs)"
  [ -n "${platform}" ] || continue
  sync_platform "${platform}"
done

x64_output="$(framework_output_for_platform linux-x64)"
default_output="${FRAMEWORK_DIR}/SnowLuma.Framework.tar.gz"
if [ -f "${x64_output}" ]; then
  cp "${x64_output}" "${default_output}"
  echo "Wrote ${default_output} (linux-x64 alias)"
fi

synced_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
mkdir -p "$(dirname "${LOCK_FILE}")"
jq -n \
  --arg sha "${HEAD_SHA}" \
  --argjson run_id "${RUN_ID}" \
  --arg synced_at "${synced_at}" \
  '{
    sha: $sha,
    run_id: $run_id,
    synced_at: $synced_at,
    platforms: {}
  }' > "${LOCK_FILE}"

for raw_platform in "${PLATFORM_LIST[@]}"; do
  platform="$(echo "${raw_platform}" | xargs)"
  [ -n "${platform}" ] || continue
  tmp="$(mktemp)"
  jq \
    --arg platform "${platform}" \
    --arg sha "${HEAD_SHA}" \
    --argjson run_id "${RUN_ID}" \
    --arg synced_at "${synced_at}" \
    --arg file "SnowLuma.Framework.${platform}.tar.gz" \
    '.platforms[$platform] = { sha: $sha, run_id: $run_id, synced_at: $synced_at, file: $file }' \
    "${LOCK_FILE}" > "${tmp}"
  mv "${tmp}" "${LOCK_FILE}"
done

echo "Updated ${LOCK_FILE}"
