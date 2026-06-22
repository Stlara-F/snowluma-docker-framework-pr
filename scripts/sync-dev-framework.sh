#!/usr/bin/env bash
# Download upstream Dev Build lite tarballs into the repo root.
#
# Environment variables:
#   SNOWLUMA_REPO            - upstream repo (default: SnowLuma/SnowLuma)
#   HEAD_SHA                 - commit SHA (required)
#   RUN_ID                   - workflow run ID (required)
#   PLATFORMS                - comma-separated platforms (default: linux-x64,linux-arm64)
#   ARTIFACT_NAME_TEMPLATE   - template with {sha}, {platform}, etc.
#   SOURCE_BRANCH            - branch for template (default: dev)
#   WORKFLOW_NAME            - workflow name for template (default: Dev Build)
#   LITE_TARBALL_PATTERN     - suffix to identify lite tarballs (default: -lite.tar.gz)
#
# Template placeholders:
#   {sha}, {sha_short}, {branch}, {platform}, {workflow},
#   {repo_owner}, {repo_name}, {repo}
#
# Requires: gh CLI (https://cli.github.com/), unzip
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SNOWLUMA_REPO="${SNOWLUMA_REPO:-SnowLuma/SnowLuma}"
PLATFORMS="${PLATFORMS:-linux-x64,linux-arm64}"
HEAD_SHA="${HEAD_SHA:-}"
RUN_ID="${RUN_ID:-}"
SOURCE_BRANCH="${SOURCE_BRANCH:-dev}"
WORKFLOW_NAME="${WORKFLOW_NAME:-Dev Build}"
ARTIFACT_NAME_TEMPLATE="${ARTIFACT_NAME_TEMPLATE:-SnowLuma-dev-{sha}-{platform}}"
LITE_TARBALL_PATTERN="${LITE_TARBALL_PATTERN:--lite.tar.gz}"

[ -n "${HEAD_SHA}" ] && [ -n "${RUN_ID}" ] || {
  echo "HEAD_SHA and RUN_ID are required." >&2; exit 1
}

command -v gh >/dev/null 2>&1 || { echo "gh CLI not found." >&2; exit 1; }
command -v unzip >/dev/null 2>&1 || { echo "unzip is required." >&2; exit 1; }

framework_output_for_platform() {
  printf '%s/SnowLuma.Framework.%s.tar.gz' "${FRAMEWORK_DIR}" "$1"
}

# ── Resolve artifact name from template ──
resolve_artifact_name() {
  local platform="$1"
  local repo_owner="${SNOWLUMA_REPO%%/*}"
  local repo_name="${SNOWLUMA_REPO#*/}"
  local sha_short="${HEAD_SHA:0:12}"
  local name="$ARTIFACT_NAME_TEMPLATE"
  name="${name//\{sha\}/$HEAD_SHA}"
  name="${name//\{sha_short\}/$sha_short}"
  name="${name//\{branch\}/$SOURCE_BRANCH}"
  name="${name//\{platform\}/$platform}"
  name="${name//\{workflow\}/$WORKFLOW_NAME}"
  name="${name//\{repo_owner\}/$repo_owner}"
  name="${name//\{repo_name\}/$repo_name}"
  name="${name//\{repo\}/$SNOWLUMA_REPO}"
  printf '%s\n' "$name"
}

# ── Find lite tarball in downloaded artifact ──
find_lite_tarball() {
  local download_dir="$1"
  local platform="$2"
  local artifact_name="$3"
  local lite_name zip_path lite_path

  lite_name="${artifact_name}${LITE_TARBALL_PATTERN}"
  zip_path="${download_dir}/${artifact_name}.zip"

  if [ -f "${download_dir}/${lite_name}" ]; then
    printf '%s\n' "${download_dir}/${lite_name}"
    return 0
  fi
  if [ -f "${zip_path}" ]; then
    unzip -qo "${zip_path}" -d "${download_dir}/extracted"
    lite_path="${download_dir}/extracted/${lite_name}"
    [ -f "${lite_path}" ] && { printf '%s\n' "${lite_path}"; return 0; }
  fi

  zip_path="$(find "${download_dir}" -maxdepth 1 -type f -name '*.zip' | head -n 1)"
  if [ -n "${zip_path}" ]; then
    unzip -qo "${zip_path}" -d "${download_dir}/extracted"
    lite_path="$(find "${download_dir}/extracted" -maxdepth 1 -type f -name "*${LITE_TARBALL_PATTERN}" | head -n 1)"
    [ -n "${lite_path}" ] && { printf '%s\n' "${lite_path}"; return 0; }
  fi

  lite_path="$(find "${download_dir}" -maxdepth 2 -type f -name "*${LITE_TARBALL_PATTERN}" | head -n 1)"
  [ -n "${lite_path}" ] && { printf '%s\n' "${lite_path}"; return 0; }

  return 1
}

# ── Sync single platform ──
sync_platform() {
  local platform="$1"
  local output artifact_name download_dir lite_path

  output="$(framework_output_for_platform "${platform}")"
  artifact_name="$(resolve_artifact_name "${platform}")"
  download_dir="$(mktemp -d)"

  echo "Downloading ${artifact_name} from run ${RUN_ID} (${SNOWLUMA_REPO})"
  gh run download "${RUN_ID}" \
    --repo "${SNOWLUMA_REPO}" \
    --name "${artifact_name}" \
    --dir "${download_dir}"

  if ! lite_path="$(find_lite_tarball "${download_dir}" "${platform}" "${artifact_name}")"; then
    echo "Expected lite tarball not found under ${download_dir}" >&2
    find "${download_dir}" -type f >&2 || true
    rm -rf "${download_dir}"
    return 1
  fi

  cp "${lite_path}" "${output}"
  rm -rf "${download_dir}"
  echo "Wrote ${output}"
}

# ── Main ──
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
