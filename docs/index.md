# Fluid Transcription Docs

Fluid Transcription is a native macOS CLI for transcription, speaker diarization, and combined processing of audio or video inputs.

This documentation is structured as a future documentation site rather than a single flat note, so it can grow with the project and later be published online without reorganizing the content.

## Core Concepts

- The app is a Swift Package Manager executable.
- The CLI depends directly on FluidAudio.
- It produces stable run directories with JSON artifacts intended for both humans and automation.
- It normalizes problematic inputs before inference when necessary.

## Start Here

- Read [Getting Started Overview](getting-started/overview.md) for the product scope.
- Read [Installation](getting-started/installation.md) to install the CLI from a GitHub release or Homebrew.
- Read [Quickstart](getting-started/quickstart.md) for the shortest usable path.

The preferred installed command is `ft`, with `fluid-transcription` kept as a compatibility alias.

## Main User Topics

- [CLI Overview](usage/cli-overview.md)
- [Commands](usage/commands.md)
- [Output Artifacts](usage/output-artifacts.md)
- [Input Preparation](usage/input-preparation.md)

## For Developers

- [System Overview](architecture/system-overview.md)
- [Processing Flow](architecture/processing-flow.md)
- [Local Development](development/local-development.md)
- [Release Process](development/release-process.md)
- [Publishing Docs](development/publishing-docs.md)

## Current Boundaries

- macOS-only
- Models are downloaded on first use
- Output schema is still marked draft
- Transcript segmentation and transcript-to-speaker alignment are intentionally limited in the current release