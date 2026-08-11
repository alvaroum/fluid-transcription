# Fluid Transcription

Fluid Transcription is a native macOS command-line application for speech transcription, speaker diarization, and combined meeting-processing workflows.

It is built in Swift, uses FluidAudio directly as a package dependency, and produces deterministic run directories with machine-readable JSON artifacts for downstream automation.

## What It Does

- Transcribes audio or video files to text.
- Optionally includes approximate word-level start and end times.
- Detects speaker turns and aggregates speaker talk time.
- Runs both tasks together in one `process` command.
- Validates previously generated run directories.
- Normalizes fragile or compressed inputs automatically before model execution when required.

## Current Status

- Platform: macOS 14+
- Language/toolchain: Swift 6 / Swift Package Manager
- Audio engine: FluidAudio `0.15.5`
- CLI version: `202604.5`
- Output schema version: `1.0.0-draft`

## Install

### Direct download

```bash
# Download the .pkg from the latest GitHub release and open it.
# It installs ft into /usr/local/bin and also adds a fluid-transcription compatibility alias.
open https://github.com/alvaroum/fluid-transcription/releases/latest
swift build
./.build/debug/FluidTranscriptionCLI version
./.build/debug/FluidTranscriptionCLI --help
```

```

The installer package is not signed or notarized yet, so macOS may require a one-time confirmation in Privacy & Security before installation.

### Homebrew

```bash
brew tap alvaroum/fluid-transcription
brew install fluid-transcription
```

This uses the app-specific Homebrew tap backed by the repository `alvaroum/homebrew-fluid-transcription`.

Tagged releases generate the Homebrew formula automatically and publish it as a release asset; the release workflow also updates the tap repository when the `HOMEBREW_TAP_TOKEN` secret is configured.

### Optional codec fallback

```bash
brew install ffmpeg
```

## Quick Start

### 1. Check the CLI surface

```bash
ft --help
```

### 2. Run a full processing job

```bash
ft process \
  --input ./meeting.m4a \
  --output ./runs
```

Add `--word-timestamps` when `transcript.json` should include timed words:

```bash
ft process \
  --input ./meeting.m4a \
  --output ./runs \
  --word-timestamps
```

### 3. Validate the generated run

```bash
ft validate \
  --run-dir ./runs/<job-id>
```

The release packages also install `fluid-transcription` as a compatibility alias for existing scripts.

## Commands

### `process`

Runs transcription and diarization together. Add `--word-timestamps` to include timed words in `transcript.json`. The command writes:

- `run.json`
- `events.jsonl`
- `transcript.json`
- `diarization.json`
- `combined.json`
- `combined.md`

### `transcribe`

Runs speech-to-text only. Add `--word-timestamps` to include timed words in `transcript.json`. The command writes:

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
- `transcript.json`: transcript content, metadata, and optional word timings
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

### Dependency maintenance

When a SwiftPM dependency needs to move to a known target version, use the repo script instead of manually editing source, docs, and sample artifacts:

```bash
./scripts/update-swiftpm-dependency.swift fluidaudio 0.15.5
```

This updates the declared requirement in `Package.swift`, runs `swift package resolve`, and then syncs any mirrored version strings configured in `scripts/dependency-sync.json`.

After running it, verify:

```bash
swift build
./.build/debug/FluidTranscriptionCLI version
```

### GitHub workflows

- `.github/workflows/test.yml`: build and smoke-check the package
- `.github/workflows/release.yml`: build, package, checksum, and publish tagged releases, including a `.pkg` installer, Homebrew-ready tarball, and Homebrew formula sync
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
- Transcript segmentation is currently coarse and emitted as a single segment
- Optional word timings are approximate decoder-derived values rather than forced alignment
- Transcript-to-speaker alignment is not yet implemented beyond separate diarization turn output

## Documentation Follow-Ups

- Add a changelog page once releases are more frequent
- Add API-level schema documentation if the JSON contract stabilizes
- Add screenshots later if a published docs theme or terminal capture style is standardized