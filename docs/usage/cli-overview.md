# CLI Overview

The application command name is:

```bash
fluid-transcription
```

For local development inside the repository, the release build path is:

```bash
./.build/release/FluidTranscriptionCLI
```

## Command Surface

- `version`
- `validate`
- `transcribe`
- `diarize`
- `process`

## Common Options

Run commands share a common pattern:

```bash
--input <path>
--output <directory>
--job-id <optional-id>
--overwrite
```

## Output Philosophy

The CLI is designed to emit:

- stable directory-oriented outputs
- machine-readable JSON contracts
- explicit lifecycle events
- optional Markdown summaries for human review

## Model Behavior

- ASR models are downloaded automatically on first use and then cached by FluidAudio.
- `transcribe` and `process` support model version selection.
- `v2` is English-only.
- `v3` is multilingual and the default.

## Validation Model

The CLI does not only generate outputs. It also provides a `validate` command so pipelines can assert that a run directory conforms to the expected structure.