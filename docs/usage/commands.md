# Commands

## `version`

Prints a JSON payload containing:

- app name
- app version
- schema version
- FluidAudio version
- model download note

Example:

```bash
./.build/release/FluidTranscriptionCLI version
```

## `transcribe`

Transcribes an input file and writes:

- `run.json`
- `events.jsonl`
- `transcript.json`

Example:

```bash
./.build/release/FluidTranscriptionCLI transcribe \
  --input ./meeting.m4a \
  --output ./runs \
  --model-version v3
```

## `diarize`

Runs speaker diarization and writes:

- `run.json`
- `events.jsonl`
- `diarization.json`

Example:

```bash
./.build/release/FluidTranscriptionCLI diarize \
  --input ./meeting.m4a \
  --output ./runs
```

## `process`

Runs transcription and diarization together and writes:

- `run.json`
- `events.jsonl`
- `transcript.json`
- `diarization.json`
- `combined.json`
- `combined.md`

Example:

```bash
./.build/release/FluidTranscriptionCLI process \
  --input ./meeting.m4a \
  --output ./runs \
  --overwrite
```

## `validate`

Checks whether a previously generated run directory matches the expected output contract.

Example:

```bash
./.build/release/FluidTranscriptionCLI validate \
  --run-dir ./runs/example-job
```

## Exit Expectations

- Successful generation commands write a completed `run.json` and emit the run metadata to stdout.
- Failed generation commands still write failure state into the run directory when possible.
- `validate` exits non-zero when the report is not `ok`.