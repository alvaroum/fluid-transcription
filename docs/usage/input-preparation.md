# Input Preparation

## Why Input Preparation Exists

Some compressed or containerized inputs are not reliable when sent directly into the model-facing decode path.

The CLI now owns a preparation layer so that users can pass original media files directly without manually converting them first.

## Current Behavior

### WAV inputs

If the input extension is `.wav`, the file is passed through as-is.

### Non-WAV inputs

If the input is not `.wav`, the CLI attempts to normalize it to a temporary mono 16 kHz WAV before processing.

## Strategy Order

1. AVFoundation decode
2. `ffmpeg` fallback if AVFoundation does not succeed

## Event Logging

When preparation occurs, `events.jsonl` records:

- `event`: `input_prepared`
- `details.strategy`: `avfoundation` or `ffmpeg`

## Temporary Files

Prepared media is written to a temporary directory and cleaned up after the run command completes.

## Operational Benefit

This moves codec/container handling into the app layer and avoids requiring users to pre-convert problematic inputs manually.