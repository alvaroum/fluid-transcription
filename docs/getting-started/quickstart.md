# Quickstart

## Build

```bash
swift build -c release
```

## Run the main workflow

```bash
./.build/release/FluidTranscriptionCLI process \
  --input ./meeting.m4a \
  --output ./runs
```

## Inspect the result

Each run gets its own output directory under `./runs`.

Typical contents:

- `run.json`
- `events.jsonl`
- `transcript.json`
- `diarization.json`
- `combined.json`
- `combined.md`

## Validate the run

```bash
./.build/release/FluidTranscriptionCLI validate \
  --run-dir ./runs/<job-id>
```

## Common Alternatives

Transcription only:

```bash
./.build/release/FluidTranscriptionCLI transcribe \
  --input ./meeting.m4a \
  --output ./runs
```

Diarization only:

```bash
./.build/release/FluidTranscriptionCLI diarize \
  --input ./meeting.m4a \
  --output ./runs
```

## What Happens Behind the Scenes

For non-WAV inputs, the CLI may create a temporary normalized WAV before model execution.

If normalization occurs, an `input_prepared` event is written to `events.jsonl` with the strategy used.