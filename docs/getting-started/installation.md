# Installation

## Requirements

- macOS 14 or later
- Swift 6 toolchain with Swift Package Manager
- Network access on first model download
- Optional: `ffmpeg` for fallback input normalization

## Clone and Build

```bash
git clone <your-repo-url>
cd "Fluid Transcription"
swift build -c release
```

The release executable will be available at:

```bash
./.build/release/FluidTranscriptionCLI
```

## Optional `ffmpeg`

The application first attempts native AVFoundation decoding for non-WAV inputs.

If that fails and `ffmpeg` is available, it uses `ffmpeg` as a fallback normalization layer.

Homebrew example:

```bash
brew install ffmpeg
```

## Verify the Install

```bash
./.build/release/FluidTranscriptionCLI version
./.build/release/FluidTranscriptionCLI --help
```

## Release Packaging

Tagged releases are packaged by GitHub Actions into a tarball containing:

- `bin/fluid-transcription`

See [Release Process](../development/release-process.md) for details.