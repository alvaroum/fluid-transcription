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

- `test-inputs/` and `test-runs/` are ignored because they are local artifacts.
- `site/` is ignored because it is the generated documentation output directory.
- The public Homebrew tap is `alvaroum/fluid-transcription`, backed by the repository `alvaroum/homebrew-fluid-transcription`.

## What To Verify After CLI Changes

- build succeeds in debug and release
- help text still reflects actual behavior
- a representative compressed input still processes successfully
- validation still passes on produced runs