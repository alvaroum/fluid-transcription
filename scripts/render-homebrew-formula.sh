#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <version> <sha256>" >&2
  exit 1
fi

version="$1"
sha256="$2"

cat <<EOF
class FluidTranscription < Formula
  desc "Native macOS CLI for transcription, speaker diarization, and combined media-processing workflows"
  homepage "https://github.com/alvaroum/fluid-transcription"
  url "https://github.com/alvaroum/fluid-transcription/releases/download/v${version}/fluid-transcription-${version}-macos-arm64.tar.gz"
  version "${version}"
  sha256 "${sha256}"
  license "Apache-2.0"
  depends_on arch: :arm64

  def install
    bin.install "ft"
    bin.install_symlink "ft" => "fluid-transcription"
  end

  test do
    output = shell_output("#{bin}/ft version")
    assert_match "fluid-transcription", output
  end
end
EOF