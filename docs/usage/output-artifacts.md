# Output Artifacts

Each run directory is intended to be self-contained.

## `run.json`

Top-level execution record:

- schema version
- job id
- mode
- input path
- run directory path
- creation time
- status
- artifact list

## `events.jsonl`

Append-only lifecycle events in JSON Lines format.

Typical events:

- `job_started`
- `input_prepared`
- `artifact_written`
- `job_completed`
- `job_failed`

## `transcript.json`

Transcript artifact containing:

- language
- optional duration
- tool versions
- segments
- full text
- notes

Current limitation:

- transcription currently emits a single coarse segment until richer timing extraction is implemented

## `diarization.json`

Diarization artifact containing:

- speaker summaries
- speaker turns
- optional overall duration
- tool versions

## `combined.json`

Merged high-level artifact combining:

- summary counts
- transcript full text
- diarization turns
- processing notes

## `combined.md`

Human-readable Markdown rendering of the combined result.

This is meant for review, not as the canonical contract for automation.

## Recommended Consumer Pattern

For automated consumers:

- use `run.json` to detect status and available artifacts
- use `events.jsonl` to inspect lifecycle details
- read `transcript.json`, `diarization.json`, or `combined.json` depending on the workflow

For concrete examples, see [Artifact Examples](artifact-examples.md).