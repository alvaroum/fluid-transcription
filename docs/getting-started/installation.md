# Installation

## Requirements

- macOS 14 or later
- Network access on first model download
- Optional: `ffmpeg` for fallback input normalization

## Recommended: GitHub Release Installer

```bash
open https://github.com/alvaroum/fluid-transcription/releases/latest
```

From the latest release page, download the installer package:

```bash
fluid-transcription-<version>-macos-arm64.pkg
```

Open the package and follow the macOS installer steps.

The installer places the CLI at:

```bash
/usr/local/bin/fluid-transcription
```

That location is already on the default shell `PATH` for standard macOS Terminal setups, so the command is available immediately after installation.

## Homebrew

For users who prefer package management:

```bash
brew tap alvaroum/tap
brew install fluid-transcription
```

This installs the same release binary into Homebrew's managed prefix and exposes the `fluid-transcription` command on `PATH`.

Current note:

- Homebrew installation is Apple Silicon only for now because the published binary artifacts are `macos-arm64`.
- The direct `.pkg` installer is not yet signed or notarized, so macOS may require a one-time confirmation in Privacy & Security before installation.

## Optional `ffmpeg`

The application first attempts native AVFoundation decoding for non-WAV inputs.

If that fails and `ffmpeg` is available, it uses `ffmpeg` as a fallback normalization layer.

Homebrew example:

```bash
brew install ffmpeg
```

## Verify the Install

```bash
fluid-transcription version
fluid-transcription --help
```

## Build From Source

Building from source is still supported for development work:

```bash
git clone https://github.com/alvaroum/fluid-transcription.git
cd "fluid-transcription"
swift build -c release
./.build/release/FluidTranscriptionCLI version
```

## Release Assets

Tagged releases are packaged by GitHub Actions into:

- a macOS installer package: `fluid-transcription-<version>-macos-arm64.pkg`
- a Homebrew-ready tarball: `fluid-transcription-<version>-macos-arm64.tar.gz`
- `SHA256SUMS`

See [Release Process](../development/release-process.md) for details.