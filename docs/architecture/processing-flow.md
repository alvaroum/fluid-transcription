# Processing Flow

## End-to-End Flow

For `process`, `transcribe`, and `diarize`, the high-level flow is:

1. Parse command-line arguments
2. Resolve input and output paths
3. Create the run directory
4. Emit `job_started`
5. Prepare the input if normalization is needed
6. Run model inference
7. Write artifacts
8. Emit completion or failure events
9. Write `run.json`

## `process` Command Flow

`process` performs:

1. input preparation
2. transcription
3. diarization
4. combined artifact generation
5. Markdown summary generation

## Validation Flow

The `validate` command does not run inference.

It inspects a previously generated run directory and returns a structured validation report.

## Failure Behavior

When a command fails after the run directory exists:

- a failure event is written to `events.jsonl`
- `run.json` is written with `status: failed`
- the command exits with an error

## Current Known Gaps

- transcript timing is not yet rich enough for transcript-to-speaker alignment
- the schema is still draft and may evolve