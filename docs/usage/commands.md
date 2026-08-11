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
ft version
```

## `transcribe`

Transcribes an input file and writes:

- `run.json`
- `events.jsonl`
- `transcript.json`

Example:

```bash
ft transcribe \
  --input ./meeting.m4a \
  --output ./runs \
  --model-version v3
```

Add `--word-timestamps` to include approximate word-level start and end times in `transcript.json`:

```bash
ft transcribe \
  --input ./meeting.m4a \
  --output ./runs \
  --word-timestamps
```

The `words` field is absent when the flag is omitted.

## `diarize`

Runs speaker diarization and writes:

- `run.json`
- `events.jsonl`
- `diarization.json`

Example:

```bash
ft diarize \
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
ft process \
  --input ./meeting.m4a \
  --output ./runs \
  --overwrite
```

`process` also accepts `--word-timestamps`. Timed words are written to the canonical `transcript.json` artifact rather than duplicated in `combined.json`.

## `validate`

Checks whether a previously generated run directory matches the expected output contract.

Example:

```bash
ft validate \
  --run-dir ./runs/example-job
```

## Exit Expectations

- Successful generation commands write a completed `run.json` and emit the run metadata to stdout.
- Failed generation commands still write failure state into the run directory when possible.
- `validate` exits non-zero when the report is not `ok`.