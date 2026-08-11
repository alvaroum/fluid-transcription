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
- audio duration
- tool versions
- segments
- full text
- notes

Transcription currently emits one coarse segment. When `transcribe` or `process` is run with `--word-timestamps`, that segment also contains a `words` array with `text`, `start_sec`, and `end_sec` for each timed word. The field is absent by default.

Word timings are approximate decoder-derived values grouped from FluidAudio token timings. They are not forced-alignment timestamps. SentencePiece grouping may produce larger units than orthographic words in languages that do not use spaces consistently. If timings are requested but FluidAudio returns no usable token timing data, the artifact contains an empty `words` array and an explanatory note.

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