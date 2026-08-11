# Local Development

## Basic Build Loop

```bash
swift build
./.build/debug/FluidTranscriptionCLI version
./.build/debug/FluidTranscriptionCLI --help
```

For packaged installs, the preferred command name is `ft`. Inside the repository, the executable path remains `./.build/debug/FluidTranscriptionCLI` or `./.build/release/FluidTranscriptionCLI`.

## Useful Smoke Checks

Process help surface:

```bash
./.build/debug/FluidTranscriptionCLI process --help
```

Direct-input processing check:

```bash
./.build/debug/FluidTranscriptionCLI process \
  --input ./meeting.m4a \
  --output ./test-runs \
  --overwrite
```

Run validation:

```bash
./.build/debug/FluidTranscriptionCLI validate \
  --run-dir ./test-runs/<job-id>
```

## Repository Notes

- `test-inputs/`, `test-runs/`, `graphify-out/`, and local `*.code-workspace` files are ignored because they are local artifacts.
- `site/` is ignored because it is the generated documentation output directory.
- The public Homebrew tap is `alvaroum/fluid-transcription`, backed by the repository `alvaroum/homebrew-fluid-transcription`.

## Dependency Updates

For SwiftPM dependency bumps, prefer the repo script instead of manually editing source and docs:

```bash
./scripts/update-swiftpm-dependency.swift fluidaudio 0.15.5
```

The script updates `Package.swift`, resolves the package graph, and syncs any mirrored version strings defined in `scripts/dependency-sync.json`.

It does not fix upstream API changes automatically, so still run the normal verification loop afterward.

## What To Verify After CLI Changes

- build succeeds in debug and release
- help text still reflects actual behavior
- a representative compressed input still processes successfully
- validation still passes on produced runs