# Fluid Transcription

Fluid Transcription is a native macOS command-line application for speech transcription, speaker diarization, and combined meeting-processing workflows.

It is built in Swift, uses FluidAudio directly as a package dependency, and produces deterministic run directories with machine-readable JSON artifacts for downstream automation.

## What It Does

- Transcribes audio or video files to text.
- Detects speaker turns and aggregates speaker talk time.
- Runs both tasks together in one `process` command.
- Validates previously generated run directories.
- Normalizes fragile or compressed inputs automatically before model execution when required.

## Current Status

- Platform: macOS 14+
- Language/toolchain: Swift 6 / Swift Package Manager
- Audio engine: FluidAudio `0.13.6`
- CLI version: `202604.2`
- Output schema version: `1.0.0-draft`

## Quick Start

### 1. Build

```bash
swift build -c release
```

### 2. Check the CLI surface

```bash
./.build/release/FluidTranscriptionCLI --help
```

### 3. Run a full processing job

```bash
./.build/release/FluidTranscriptionCLI process \
  --input ./meeting.m4a \
  --output ./runs
```

### 4. Validate the generated run

```bash
./.build/release/FluidTranscriptionCLI validate \
  --run-dir ./runs/<job-id>
```

## Commands

### `process`

Runs transcription and diarization together and writes:

- `run.json`
- `events.jsonl`
- `transcript.json`
- `diarization.json`
- `combined.json`
- `combined.md`

### `transcribe`

Runs speech-to-text only and writes:

- `run.json`
- `events.jsonl`
- `transcript.json`

### `diarize`

Runs speaker diarization only and writes:

- `run.json`
- `events.jsonl`
- `diarization.json`

### `validate`

Validates a previously generated run directory against the current output contract.

### `version`

Prints app, schema, and FluidAudio version information as JSON.

## Input Handling

The CLI accepts audio or video files.

For compressed or fragile inputs, it prepares a temporary normalized PCM WAV before inference:

- First choice: native AVFoundation decode
- Fallback: `ffmpeg`, when available

This protects the workflow from codec/container combinations that are not robust in the direct decode path.

## Output Model

Each run is written to its own directory under the selected output folder.

Artifacts are designed for both human review and automation:

- `run.json`: top-level run metadata and status
- `events.jsonl`: lifecycle events such as `job_started`, `input_prepared`, and `job_completed`
- `transcript.json`: transcript content and metadata
- `diarization.json`: speaker summaries and turns
- `combined.json`: merged high-level artifact for downstream consumers
- `combined.md`: Markdown rendering of the combined result for human reading

## Development

### Local smoke check

```bash
swift build
./.build/debug/FluidTranscriptionCLI version
./.build/debug/FluidTranscriptionCLI process --help
```

### GitHub workflows

- `.github/workflows/test.yml`: build and smoke-check the package
- `.github/workflows/release.yml`: build, package, checksum, and publish tagged releases
- `.github/workflows/docs.yml`: build and deploy the documentation site to GitHub Pages

## Documentation

Longer-form documentation lives in `docs/` and is organized so it can later be published as a documentation site.

- `docs/index.md`: documentation landing page
- `docs/getting-started/`: install, requirements, and quickstart material
- `docs/usage/`: command usage and output contracts
- `docs/architecture/`: system design and execution flow
- `docs/development/`: local development, releases, and future publication

The docs now also include example artifact snippets so consumers can understand the JSON shape before integrating against it.

An initial `mkdocs.yml` is included so the docs can be served or published later with minimal restructuring.

## License

This project is licensed under Apache License 2.0. See `LICENSE`.

## Limitations

- macOS-only at the moment
- Models are not bundled into the repository; FluidAudio downloads required models on first use
- Transcript segmentation is currently coarse and emitted as a single segment until richer ASR timing extraction is added
- Transcript-to-speaker alignment is not yet implemented beyond separate diarization turn output

## Documentation Follow-Ups

- Add a changelog page once releases are more frequent
- Add API-level schema documentation if the JSON contract stabilizes
- Add screenshots later if a published docs theme or terminal capture style is standardized