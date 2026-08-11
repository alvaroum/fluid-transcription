# Changelog

All notable changes to this project will be documented in this file.

## Unreleased

- Updated FluidAudio from `0.14.5` to `0.15.5` and swift-argument-parser from `1.7.1` to `1.8.2`.
- Added automated GitHub release notes generation from `CHANGELOG.md`, with a commit-history fallback in the release workflow.

## v202604.5 - 2026-05-12

- Upgraded the FluidAudio dependency to `0.14.5` and adapted the transcription path to the current decoder-state API.
- Added `scripts/update-swiftpm-dependency.swift` and `scripts/dependency-sync.json` to turn dependency version updates into a single repo command.
- Added a CI dependency metadata sync check in `.github/workflows/test.yml` so mirrored dependency versions cannot silently drift from `Package.resolved`.
- Updated development documentation to describe the new maintenance workflow.