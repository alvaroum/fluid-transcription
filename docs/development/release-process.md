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
5. Build a macOS installer package that installs into `/usr/local/bin`
6. Create a Homebrew-ready tarball
7. Generate SHA256 checksums for both distributables
8. Generate the matching Homebrew formula
9. Update the Homebrew tap repository when the release token is available
10. Publish the GitHub release assets

## Produced Release Assets

```text
release/
  fluid-transcription-<version>-macos-arm64.pkg
  fluid-transcription-<version>-macos-arm64.tar.gz
  fluid-transcription.rb
  SHA256SUMS
```

## Tarball Layout

```text
release/
  bin/
    ft
    fluid-transcription -> ft
```

## Notes

- The packaged primary command name is `ft`.
- The release artifacts also include `fluid-transcription` as a compatibility symlink.
- The SwiftPM target name remains `FluidTranscriptionCLI`.
- The Homebrew tap name is `alvaroum/fluid-transcription`, backed by the repository `alvaroum/homebrew-fluid-transcription`.
- The release workflow updates the tap automatically when the repository secret `HOMEBREW_TAP_TOKEN` is configured with write access to `alvaroum/homebrew-fluid-transcription`.
- Direct downloads should use the `.pkg` installer; the tarball is primarily for Homebrew and advanced manual installation.
- Models are not bundled into the release artifact.
- The current public release line for this repository is `v202604.5`.
- Update `CHANGELOG.md` before tagging a new release so the repository history ships with the version bump.
- The release workflow now uses the matching `CHANGELOG.md` section as the GitHub release body when it exists.
- If a matching changelog section is missing, the workflow falls back to generating release notes from commit subjects since the previous tag.

## Suggested Future Enhancements

- Apple Developer signing and notarization for the installer package
- release notes generation
- changelog automation
- docs-site deployment on tagged releases