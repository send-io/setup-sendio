#!/usr/bin/env bash
# Install step of the setup-sendio composite action. Inputs arrive as
# SETUP_SENDIO_* env vars (see action.yml). SETUP_SENDIO_DOWNLOAD_BASE and
# SETUP_SENDIO_GITHUB_API override the GitHub URLs (for testing).
set -euo pipefail

version="${SETUP_SENDIO_VERSION:-latest}"
repo="${SETUP_SENDIO_REPO:-send-io/cli}"
download_base="${SETUP_SENDIO_DOWNLOAD_BASE:-https://github.com/${repo}/releases/download}"
github_api="${SETUP_SENDIO_GITHUB_API:-https://api.github.com}"

case "${SETUP_SENDIO_RUNNER_OS:-}" in
  Linux) os=linux ext=tar.gz exe=sendio ;;
  macOS) os=darwin ext=tar.gz exe=sendio ;;
  Windows) os=windows ext=zip exe=sendio.exe ;;
  *) echo "::error::setup-sendio: unsupported runner OS '${SETUP_SENDIO_RUNNER_OS:-}'"; exit 1 ;;
esac
case "${SETUP_SENDIO_RUNNER_ARCH:-}" in
  X64) arch=amd64 ;;
  ARM64) arch=arm64 ;;
  *) echo "::error::setup-sendio: unsupported runner arch '${SETUP_SENDIO_RUNNER_ARCH:-}' (supported: X64, ARM64)"; exit 1 ;;
esac

if [ -z "$version" ] || [ "$version" = latest ]; then
  auth=()
  if [ -n "${SETUP_SENDIO_TOKEN:-}" ]; then auth=(-H "Authorization: Bearer ${SETUP_SENDIO_TOKEN}"); fi
  version="$(curl -fsSL --retry 3 ${auth[@]+"${auth[@]}"} -H 'Accept: application/vnd.github+json' \
    "${github_api%/}/repos/${repo}/releases/latest" |
    sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
  [ -n "$version" ] || { echo "::error::setup-sendio: could not resolve the latest release of ${repo}"; exit 1; }
fi
version="${version#v}"

archive="sendio_${version}_${os}_${arch}.${ext}"
base_url="${download_base%/}/v${version}"
work="${RUNNER_TEMP:-$(mktemp -d)}/setup-sendio-$$"
dest="${RUNNER_TOOL_CACHE:-${RUNNER_TEMP:-$work}}/sendio/${version}/${arch}"
mkdir -p "$work" "$dest"
trap 'rm -rf "$work"' EXIT

echo "Downloading sendio ${version} (${os}/${arch})"
curl -fsSL --retry 3 -o "${work}/${archive}" "${base_url}/${archive}"
curl -fsSL --retry 3 -o "${work}/checksums.txt" "${base_url}/checksums.txt"

expected="$(awk -v f="$archive" '$2 == f || $2 == "*" f {print $1}' "${work}/checksums.txt" | head -n 1)"
[ -n "$expected" ] || { echo "::error::setup-sendio: no checksum for ${archive}"; exit 1; }
if command -v sha256sum >/dev/null 2>&1; then
  actual="$(sha256sum < "${work}/${archive}" | awk '{print $1}')" # stdin: no file name, so Git Bash on Windows prints no leading backslash
else
  actual="$(shasum -a 256 < "${work}/${archive}" | awk '{print $1}')"
fi
if [ "$expected" != "$actual" ]; then
  echo "::error::setup-sendio: checksum mismatch for ${archive} (expected ${expected}, got ${actual})"
  exit 1
fi
echo "Checksum verified (sha256 ${actual})"

if [ "$ext" = zip ]; then
  if command -v unzip >/dev/null 2>&1; then
    unzip -o -q "${work}/${archive}" -d "${work}/x"
  else
    pwsh -NoProfile -Command "Expand-Archive -LiteralPath '${work}/${archive}' -DestinationPath '${work}/x' -Force"
  fi
else
  mkdir -p "${work}/x"
  tar -xzf "${work}/${archive}" -C "${work}/x"
fi
cp "${work}/x/${exe}" "${dest}/${exe}"
chmod +x "${dest}/${exe}"

echo "$dest" >> "${GITHUB_PATH:-/dev/null}"
{
  echo "version=${version}"
  echo "path=${dest}/${exe}"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"
echo "Installed sendio ${version} to ${dest}/${exe}"
