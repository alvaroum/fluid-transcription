# Getting Started Overview

Fluid Transcription is designed for local, scriptable media processing on macOS.

The preferred installed command is `ft`.

Release packages and Homebrew also provide `fluid-transcription` as a compatibility alias for existing scripts.

The CLI currently exposes five commands:

- `process`
- `transcribe`
- `diarize`
- `validate`
- `version`

## Intended Use Cases

- Batch-processing meeting recordings
- Producing machine-readable transcripts for AI-agent workflows
- Generating speaker-turn timelines for review pipelines
- Validating output directories in automation or CI steps

## Design Principles

- Native Swift implementation
- Deterministic output layout
- JSON-first artifacts
- Minimal command surface
- Safe handling of codec/container edge cases through normalization

## License

The project is licensed under Apache License 2.0.

## What Makes This Repo Different

This repository is not a wrapper around a separate transcription binary.

Instead, it links FluidAudio directly and exposes a small app layer that handles:

- CLI argument parsing
- run-directory creation
- artifact generation
- validation
- input preparation before model execution

## Recommended Reading Order

1. [Installation](installation.md)
2. [Quickstart](quickstart.md)
3. [Commands](../usage/commands.md)
4. [Output Artifacts](../usage/output-artifacts.md)