# System Overview

## Architecture Summary

The repository is a Swift Package Manager application with a single executable target.

Primary layers:

- CLI layer
- app-core artifact layer
- input-preparation layer
- FluidAudio-backed engine layer

## Main Source Files

- `Sources/FluidTranscriptionCLI/main.swift`
- `Sources/FluidTranscriptionCLI/AppCore.swift`
- `Sources/FluidTranscriptionCLI/InputPreparation.swift`
- `Sources/FluidTranscriptionCLI/Engine.swift`

## Responsibilities

### `main.swift`

Defines:

- commands
- help text
- option parsing
- run orchestration
- stdout behavior

### `AppCore.swift`

Defines:

- constants
- artifact models
- run-directory creation
- event writing
- validation helpers

### `InputPreparation.swift`

Defines:

- passthrough behavior for WAV inputs
- AVFoundation-based normalization
- `ffmpeg` fallback normalization
- temporary file cleanup

### `Engine.swift`

Defines:

- ASR interaction via FluidAudio
- diarization interaction via FluidAudio
- translation from engine output into repo artifact types

## External Dependencies

- `swift-argument-parser`
- `FluidAudio`
- native macOS frameworks for media decoding
- optional `ffmpeg` executable for fallback normalization