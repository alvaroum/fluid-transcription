# Quickstart

## Install

```bash
fluid-transcription --help
```

## Run the main workflow

```bash
fluid-transcription process \
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
fluid-transcription validate \
  --run-dir ./runs/<job-id>
```

## Common Alternatives

Transcription only:

```bash
fluid-transcription transcribe \
  --input ./meeting.m4a \
  --output ./runs
```

Diarization only:

```bash
fluid-transcription diarize \
  --input ./meeting.m4a \
  --output ./runs
```

## What Happens Behind the Scenes

For non-WAV inputs, the CLI may create a temporary normalized WAV before model execution.

If normalization occurs, an `input_prepared` event is written to `events.jsonl` with the strategy used.