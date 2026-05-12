#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <version> <sha256> <tap-repo>" >&2
  exit 1
fi

if [[ -z "${HOMEBREW_TAP_TOKEN:-}" ]]; then
  echo "HOMEBREW_TAP_TOKEN is required" >&2
  exit 1
fi

version="$1"
sha256="$2"
tap_repo="$3"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

git clone "https://x-access-token:${HOMEBREW_TAP_TOKEN}@github.com/${tap_repo}.git" "$work_dir/tap"

mkdir -p "$work_dir/tap/Formula"
"$script_dir/render-homebrew-formula.sh" "$version" "$sha256" > "$work_dir/tap/Formula/fluid-transcription.rb"

pushd "$work_dir/tap" >/dev/null

if git diff --quiet -- Formula/fluid-transcription.rb; then
  echo "Homebrew tap is already up to date."
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add Formula/fluid-transcription.rb
git commit -m "Update fluid-transcription to ${version}"
git push origin HEAD

popd >/dev/null