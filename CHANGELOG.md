# Changelog

All notable changes to this project will be documented in this file.

## v202604.5 - 2026-05-12

- Upgraded the FluidAudio dependency to `0.14.5` and adapted the transcription path to the current decoder-state API.
- Added `scripts/update-swiftpm-dependency.swift` and `scripts/dependency-sync.json` to turn dependency version updates into a single repo command.
- Added a CI dependency metadata sync check in `.github/workflows/test.yml` so mirrored dependency versions cannot silently drift from `Package.resolved`.
- Updated development documentation to describe the new maintenance workflow.