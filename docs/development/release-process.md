# Release Process

## GitHub Workflow

Release packaging is defined in `.github/workflows/release.yml`.

It runs on pushed tags matching:

```text
v*
```

Release tags are expected to use the format:

```text
vyyyymm.i
```

Example:

```text
v202604.1
```

If a tag is already pushed and you need to fix the workflow or packaging, publish the next iteration instead of rewriting an existing release tag.

## Current Release Steps

1. Build the Swift package
2. Smoke-run the `version` command
3. Build the release binary
4. Stage a `release/bin` layout
5. Rename the distributable binary to `fluid-transcription`
6. Create a tarball
7. Generate SHA256 checksums
8. Publish the GitHub release assets

## Produced Archive Layout

```text
release/
  bin/
    fluid-transcription
```

## Notes

- The packaged binary name is `fluid-transcription`.
- The SwiftPM target name remains `FluidTranscriptionCLI`.
- Models are not bundled into the release artifact.
- The current public release line for this repository is `v202604.2`.

## Suggested Future Enhancements

- notarization and signing
- release notes generation
- changelog automation
- docs-site deployment on tagged releases