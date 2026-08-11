# Optional Word-Level Timestamps Implementation Plan

**Goal:** Add an opt-in `--word-timestamps` mode to `ft transcribe` and `ft process` that writes the most precise word-level start/end times available from FluidAudio while leaving the default transcript output free of word-level timing data.

**Architecture:** Continue using the existing FluidAudio `AsrManager` transcription path. FluidAudio 0.15.5 already returns `ASRResult.tokenTimings` and exposes `buildWordTimings(from:)`, so the app only needs to aggregate those token timings into words and serialize them conditionally. Store optional words inside the existing transcript segment, preserving the current single-segment design and avoiding a second inference or forced-alignment pass.

**Tech Stack:** Swift 6, Swift Package Manager, swift-argument-parser 1.8.2, FluidAudio 0.15.5, Swift Testing/XCTest-compatible SwiftPM test target.

---

## Feasibility assessment

**Verdict: feasible with low-to-moderate implementation risk.**

Evidence from the current app:

- `Sources/FluidTranscriptionCLI/Engine.swift:19-47` already receives a FluidAudio `ASRResult`, but currently keeps only `result.text` and `result.confidence`.
- FluidAudio 0.15.5 defines `ASRResult.tokenTimings: [TokenTiming]?`; each token includes `startTime`, `endTime`, and confidence.
- FluidAudio 0.15.5 exposes the public `buildWordTimings(from:)` helper, which groups SentencePiece subword tokens into `WordTiming` values with `word`, `startTime`, and `endTime`.
- The current `TranscriptSegmentArtifact` already has optional segment start/end fields, so word timing is a natural additive extension.
- The ASR decoder already produces token timings during normal inference. Enabling output should add only small O(n) aggregation/serialization costs, not a second model run.

Important limits:

- These are decoder-derived timings, not forced-alignment ground truth. FluidAudio currently uses encoder-frame timing and emission-delay correction; practical precision is approximately frame-level rather than sample-level.
- Word end times may be inferred from token duration or the next token start. The last token can use a one-frame fallback.
- SentencePiece boundaries determine “words.” Results should be strong for whitespace-delimited languages, but v3 multilingual output for languages without conventional spaces may represent lexical units rather than linguistically perfect words.
- Punctuation and special-token behavior follows FluidAudio’s `buildWordTimings(from:)` implementation.
- FluidAudio can return missing or empty token timings. An explicitly requested but unavailable result must be represented honestly as an empty word list plus a note, not fabricated times.
- This feature does not yet align words to diarized speakers. That should remain a separate future feature.

## Proposed user-facing contract

### CLI

```bash
# Existing/default behavior: no word array in transcript.json
ft transcribe --input meeting.m4a --output ./runs

# Opt-in detailed timing
ft transcribe --input meeting.m4a --output ./runs --word-timestamps

# Also available in combined processing
ft process --input meeting.m4a --output ./runs --word-timestamps
```

The flag must not appear on `ft diarize`.

### JSON

When the flag is omitted, the segment’s `words` key is absent.

When requested and timings are available:

```json
{
  "segment_id": "seg-0001",
  "start_sec": 0.0,
  "end_sec": 1.28,
  "text": "Hello world",
  "confidence": 0.93,
  "words": [
    { "text": "Hello", "start_sec": 0.0, "end_sec": 0.48 },
    { "text": "world", "start_sec": 0.64, "end_sec": 1.28 }
  ]
}
```

When requested but FluidAudio provides no usable timing data, encode `"words": []` and add a transcript note explaining that timings were requested but unavailable. This distinguishes “not requested” from “requested but unavailable.”

## Design decisions

1. Use the explicit flag name `--word-timestamps`.
2. Add the flag to `transcribe` and `process`, not to shared run options, so `diarize` does not expose an irrelevant option.
3. Add `words: [TranscriptWordArtifact]?` to `TranscriptSegmentArtifact`:
   - `nil` when not requested, so Swift’s synthesized `Encodable` omits the key.
   - `.some([])` when requested but unavailable, so the request/result state remains observable.
4. Use FluidAudio’s public `buildWordTimings(from:)`; do not duplicate its tokenizer-boundary logic.
5. Keep one coarse transcript segment in this feature. When words exist, set that segment’s `start_sec` and `end_sec` from the first and last word.
6. Populate transcript `duration_sec` from `ASRResult.duration`, which is already available and requires no extra processing.
7. Do not add SRT/VTT, speaker attribution, sentence segmentation, token IDs, or raw subword tokens in this iteration.
8. Keep the current draft schema version unless project policy requires a bump; the change is additive and absent by default. Document the additive field clearly.

## Acceptance criteria

- Without `--word-timestamps`, generated `transcript.json` contains no `words` key.
- With `--word-timestamps`, every word timing returned by FluidAudio is serialized in chronological order with `text`, `start_sec`, and `end_sec`.
- Word spans satisfy `start_sec >= 0` and `end_sec > start_sec`.
- With timing enabled, the coarse segment bounds cover the first through last serialized word.
- Missing upstream token timings produce `words: []` and an explanatory note; no timestamps are invented.
- `ft transcribe --help` and `ft process --help` document the new flag.
- `ft diarize --help` does not expose the flag.
- Existing default CLI behavior, run structure, diarization output, and combined artifacts remain valid.
- Debug and release builds, metadata checks, unit tests, and CLI smoke tests pass.

## Product roadmap after word timestamps

The following roadmap prioritizes FluidAudio capabilities that fit the app’s batch transcription and meeting-processing purpose. These items are **not part of the word-timestamps implementation** unless explicitly added to scope later.

### Phase 1: Optional word timestamps

Implement the feature described in this plan:

- opt-in `--word-timestamps` support for `transcribe` and `process`;
- approximate word-level start and end times in `transcript.json`;
- unchanged default output when the flag is omitted;
- honest handling when FluidAudio returns no usable timings.

This phase creates the timing foundation required by later transcript-to-speaker alignment.

### Phase 2: Speaker-attributed transcripts

Combine word timings with the speaker turns already produced by `OfflineDiarizerManager`.

Proposed outcomes:

- assign each timed word to the speaker turn with the strongest temporal overlap;
- preserve an explicit unknown or ambiguous state when assignment is unreliable;
- group consecutive words into speaker-attributed transcript turns;
- add structured speaker-attributed content to `combined.json`;
- render a readable meeting transcript in `combined.md`.

This should not require another model run, but it needs documented rules for overlap, simultaneous speech, gaps, and boundary words.

### Phase 3: Speaker-count constraints

Expose FluidAudio’s offline diarization constraints through optional CLI arguments:

```bash
ft process ... --speakers 3
ft diarize ... --min-speakers 2 --max-speakers 5
```

Implementation should use:

- `OfflineDiarizerConfig.default.withSpeakers(exactly:)`; or
- `OfflineDiarizerConfig.default.withSpeakers(min:max:)`.

Validation must reject conflicting or invalid combinations. Default diarization behavior must remain unchanged when no constraints are supplied.

### Phase 4: Progress and performance metadata

Surface information FluidAudio already provides but the app currently discards:

- transcription progress for long recordings via `transcriptionProgressStream`;
- audio duration from `ASRResult.duration`;
- processing time from `ASRResult.processingTime`;
- real-time factor and available performance metrics.

Recommended behavior:

- send interactive progress to `stderr` so JSON written to `stdout` remains machine-readable;
- record coarse progress milestones in `events.jsonl` without producing excessive event volume;
- include optional processing metadata in the canonical artifacts;
- keep progress display suppressible for non-interactive automation if necessary.

FluidAudio’s disk-backed long-file processing and parallel chunk handling are already used implicitly by the current `AsrManager.transcribe(URL)` path; do not create a redundant long-recording mode.

### Phase 5: Academic custom vocabulary pilot

Prototype opt-in vocabulary boosting for names, acronyms, and specialist terminology, for example:

```bash
ft transcribe ... --vocabulary vocabulary.txt
```

The pilot should evaluate:

- FluidAudio’s `CustomVocabularyContext` simple-text and JSON loaders;
- additional CTC model download and memory requirements;
- accuracy improvements for academic terminology;
- false-positive behavior, especially for short terms;
- how detected and applied vocabulary terms should be recorded in artifacts;
- compatibility with the app’s current `AsrManager` path, because FluidAudio’s documentation and current source APIs require verification before committing to an architecture.

Do not make vocabulary boosting a default. Proceed to production only after a representative benchmark shows a useful accuracy gain without unacceptable substitutions.

### Phase 6: Model and language options

Benchmark before exposing additional FluidAudio models or language controls.

Candidates include:

- Parakeet TDT-CTC-110M as a smaller and faster option;
- the dedicated Japanese TDT model;
- selected broader-language models if there is a demonstrated use case;
- v3 language hints for script-aware filtering.

Language hints should be documented accurately: FluidAudio’s current v3 hint primarily filters writing systems, so it can help separate Latin, Cyrillic, and Greek output but does not strongly distinguish languages such as English and Dutch that share the Latin script.

### Deferred capabilities

Do not prioritize these until a concrete requirement emerges:

- live microphone or system-audio transcription;
- streaming EOU/Nemotron transcription;
- alternative streaming diarizers such as Sortformer or LS-EEND;
- standalone VAD controls;
- subtitle export in SRT or WebVTT;
- text-to-speech functionality.

These either require a substantially different session-oriented architecture or fall outside the app’s current transcription and meeting-processing purpose.

### Roadmap order

1. Optional word timestamps.
2. Speaker-attributed transcripts.
3. Exact/minimum/maximum speaker constraints.
4. Progress and performance metadata.
5. Academic custom vocabulary pilot.
6. Additional ASR model and language options after benchmarking.

---

### Task 1: Establish test infrastructure and baseline behavior

**Objective:** Add a SwiftPM test target and lock down the current default transcript JSON contract before changing it.

**Files:**
- Modify: `Package.swift`
- Create: `Tests/FluidTranscriptionCLITests/TranscriptArtifactEncodingTests.swift`

**Steps:**

1. Confirm the repository starts clean and record the baseline commit:

   ```bash
   git status --short --branch
   git rev-parse HEAD
   ```

   Expected baseline: source tree clean at or after `40d3dc0` (the plan file may be present separately).

2. Add `.testTarget(name: "FluidTranscriptionCLITests", dependencies: ["FluidTranscriptionCLI", .product(name: "FluidAudio", package: "FluidAudio")])` to `Package.swift`.

3. Write a failing encoding test that constructs a transcript segment without timing details and asserts encoded JSON has no `words` key.

4. Run:

   ```bash
   swift test --filter TranscriptArtifactEncodingTests
   ```

   Expected initially: failure because the new optional field/model does not exist yet.

5. Do not alter runtime behavior in this task.

6. Commit:

   ```bash
   git add Package.swift Tests/FluidTranscriptionCLITests/TranscriptArtifactEncodingTests.swift
   git commit -m "test: add transcript artifact coverage"
   ```

### Task 2: Extend the transcript artifact schema additively

**Objective:** Represent optional word timings without changing default serialized output.

**Files:**
- Modify: `Sources/FluidTranscriptionCLI/AppCore.swift:60-98`
- Modify: `Tests/FluidTranscriptionCLITests/TranscriptArtifactEncodingTests.swift`

**Steps:**

1. Add a Codable `TranscriptWordArtifact` with:
   - `text: String`
   - `startSec: Double` encoded as `start_sec`
   - `endSec: Double` encoded as `end_sec`

2. Add `words: [TranscriptWordArtifact]?` to `TranscriptSegmentArtifact`, encoded as `words`.

3. Update existing segment construction sites to pass `words: nil` temporarily so the package compiles.

4. Add encoding tests for both states:
   - `words == nil` omits the key.
   - `words == []` encodes an empty array.
   - populated words use snake_case timing keys and preserve order.

5. Run:

   ```bash
   swift test --filter TranscriptArtifactEncodingTests
   ```

   Expected: all artifact encoding tests pass.

6. Commit:

   ```bash
   git add Sources/FluidTranscriptionCLI/AppCore.swift Tests/FluidTranscriptionCLITests/TranscriptArtifactEncodingTests.swift
   git commit -m "feat: model optional transcript word timings"
   ```

### Task 3: Add a pure FluidAudio-to-artifact timing mapper

**Objective:** Convert FluidAudio token timings into stable app-level word artifacts without running models in unit tests.

**Files:**
- Modify: `Sources/FluidTranscriptionCLI/Engine.swift:18-48`
- Create: `Tests/FluidTranscriptionCLITests/WordTimingMappingTests.swift`

**Steps:**

1. Write failing tests using synthetic FluidAudio `TokenTiming` values:
   - SentencePiece pieces `▁Hello`, `▁wor`, `ld` become `Hello`, `world`.
   - `world` spans from the first subword start through the last subword end.
   - output remains chronological.
   - an empty input returns an empty array.
   - special tokens skipped by FluidAudio do not produce app words.

2. Add a small pure helper in `Engine.swift`, for example:

   ```swift
   func makeWordArtifacts(from tokenTimings: [TokenTiming]) -> [TranscriptWordArtifact] {
       buildWordTimings(from: tokenTimings).map {
           TranscriptWordArtifact(
               text: $0.word,
               startSec: $0.startTime,
               endSec: $0.endTime
           )
       }
   }
   ```

3. Avoid reimplementing SentencePiece grouping or timestamp calculations.

4. Run:

   ```bash
   swift test --filter WordTimingMappingTests
   ```

   Expected: all mapper tests pass without model downloads.

5. Commit:

   ```bash
   git add Sources/FluidTranscriptionCLI/Engine.swift Tests/FluidTranscriptionCLITests/WordTimingMappingTests.swift
   git commit -m "feat: map FluidAudio timings to transcript words"
   ```

### Task 4: Make timing extraction opt-in in the engine

**Objective:** Let callers request serialized word timings while preserving default behavior.

**Files:**
- Modify: `Sources/FluidTranscriptionCLI/Engine.swift:18-48`
- Modify: `Tests/FluidTranscriptionCLITests/WordTimingMappingTests.swift`
- Modify: `Tests/FluidTranscriptionCLITests/TranscriptArtifactEncodingTests.swift`

**Steps:**

1. Change the engine method to accept an explicit boolean, preferably labeled:

   ```swift
   func transcribe(
       inputURL: URL,
       modelVersion: TranscriptModelVersion,
       includeWordTimestamps: Bool = false
   ) async throws -> TranscriptArtifact
   ```

2. After transcription:
   - if false, set segment `words` to `nil` and retain nil segment bounds;
   - if true, convert `result.tokenTimings ?? []` through the helper;
   - if converted words are non-empty, use first start and last end for segment bounds;
   - if requested but empty, encode `words: []` and add an availability note;
   - use `result.duration` for transcript `duration_sec`;
   - replace the obsolete “until richer ASR timing extraction is added” note with accurate wording.

3. Extract artifact construction into a pure helper if needed so enabled/disabled behavior can be tested without model downloads.

4. Add tests covering:
   - disabled mode omits words;
   - enabled mode emits words and segment bounds;
   - enabled mode with no timings emits an empty list and note;
   - transcript duration uses the FluidAudio result duration.

5. Run:

   ```bash
   swift test
   swift build
   ```

   Expected: tests and build pass without downloading ASR models.

6. Commit:

   ```bash
   git add Sources/FluidTranscriptionCLI/Engine.swift Tests/FluidTranscriptionCLITests
   git commit -m "feat: support opt-in word timing artifacts"
   ```

### Task 5: Expose `--word-timestamps` in transcription commands

**Objective:** Add the opt-in CLI surface to `transcribe` and `process` only.

**Files:**
- Modify: `Sources/FluidTranscriptionCLI/main.swift:83-140`
- Modify: `Sources/FluidTranscriptionCLI/main.swift:196-270`
- Create: `Tests/FluidTranscriptionCLITests/CommandConfigurationTests.swift`

**Steps:**

1. Add this flag independently to `TranscribeCommand` and `ProcessCommand`, or introduce a transcript-specific option group shared only by those commands:

   ```swift
   @Flag(
       name: .customLong("word-timestamps"),
       help: "Include approximate word-level start and end times in transcript.json."
   )
   var wordTimestamps = false
   ```

2. Pass the captured flag into `engine.transcribe(...includeWordTimestamps:)` in both commands.

3. Include `word_timestamps: true|false` in the `job_started` event details for auditability, without changing the run artifact schema.

4. Add parser/help tests where practical. At minimum, smoke-test help output:

   ```bash
   swift build
   ./.build/debug/FluidTranscriptionCLI transcribe --help | grep -- '--word-timestamps'
   ./.build/debug/FluidTranscriptionCLI process --help | grep -- '--word-timestamps'
   test -z "$(./.build/debug/FluidTranscriptionCLI diarize --help | grep -- '--word-timestamps' || true)"
   ```

5. Verify a default parse leaves the flag false and explicit use sets it true.

6. Commit:

   ```bash
   git add Sources/FluidTranscriptionCLI/main.swift Tests/FluidTranscriptionCLITests/CommandConfigurationTests.swift
   git commit -m "feat: add word timestamps CLI option"
   ```

### Task 6: Update documentation and examples

**Objective:** Document the optional output accurately, including precision limits.

**Files:**
- Modify: `README.md`
- Modify: `docs/usage/commands.md`
- Modify: `docs/usage/output-artifacts.md`
- Modify: `docs/usage/artifact-examples.md`
- Modify: `docs/architecture/processing-flow.md` if it describes ASR output shaping
- Modify: `CHANGELOG.md`

**Steps:**

1. Add default and opt-in CLI examples.

2. Document that word timings:
   - are absent by default;
   - are approximate decoder/encoder-frame timings;
   - are grouped from subword tokens;
   - may be empty if FluidAudio cannot provide timings;
   - are not yet assigned to speakers.

3. Add a sanitized `transcript.json` example with `words` nested under the segment.

4. Remove the obsolete limitation saying timing extraction is not implemented; retain the limitation that the app currently emits one coarse transcript segment.

5. Add an Unreleased changelog entry.

6. Run documentation consistency searches:

   ```bash
   rg -n "word.timestamps|single coarse segment|timing extraction|TranscriptSegmentArtifact" README.md docs Sources
   git diff --check
   ```

7. Commit:

   ```bash
   git add README.md docs CHANGELOG.md
   git commit -m "docs: describe optional word timestamps"
   ```

### Task 7: Validate end-to-end behavior and compatibility

**Objective:** Prove the feature works without regressing the default path.

**Files:**
- Modify only if validation reveals defects.

**Steps:**

1. Run automated checks:

   ```bash
   ./scripts/update-swiftpm-dependency.swift --check
   swift test
   swift build
   swift build -c release
   ./.build/debug/FluidTranscriptionCLI version
   git diff --check
   ```

2. Run a default local transcription with a short representative speech fixture and verify:
   - `transcript.json` has no `words` key;
   - transcript text remains equivalent to the pre-feature path;
   - `ft validate` passes.

3. Run the same fixture with `--word-timestamps` and verify:
   - `words` is present and non-empty when FluidAudio returns timings;
   - words are chronological;
   - every end is greater than its start;
   - first/last word fit within duration tolerance;
   - segment bounds equal first/last word bounds;
   - `ft validate` passes.

4. Run `ft process` with the flag and confirm `transcript.json` contains timings while diarization and combined outputs remain valid.

5. Do not commit downloaded models, generated run directories, normalized temporary audio, `.build`, or test media containing sensitive speech.

6. Request an independent defect-focused review of the complete diff, especially:
   - absence-vs-empty JSON semantics;
   - default CLI compatibility;
   - multilingual limitations;
   - timestamp monotonicity and bounds;
   - accidental exposure of the flag on `diarize`.

7. Fix any accepted findings and rerun the full check set.

8. Final implementation commit if validation fixes were needed:

   ```bash
   git add <only-intended-files>
   git commit -m "test: validate optional word timestamps"
   ```

## Files likely to change

- `Package.swift`
- `Sources/FluidTranscriptionCLI/AppCore.swift`
- `Sources/FluidTranscriptionCLI/Engine.swift`
- `Sources/FluidTranscriptionCLI/main.swift`
- `Tests/FluidTranscriptionCLITests/TranscriptArtifactEncodingTests.swift` (new)
- `Tests/FluidTranscriptionCLITests/WordTimingMappingTests.swift` (new)
- `Tests/FluidTranscriptionCLITests/CommandConfigurationTests.swift` (new, if parser-level testing is practical)
- `README.md`
- `docs/usage/commands.md`
- `docs/usage/output-artifacts.md`
- `docs/usage/artifact-examples.md`
- `docs/architecture/processing-flow.md` (only if needed)
- `CHANGELOG.md`

## Risks and tradeoffs

- **Approximate timing:** Decoder timestamps are suitable for navigation, captions, and later speaker attribution, but should not be presented as forensic or forced-alignment precision.
- **Multilingual word boundaries:** SentencePiece grouping may not correspond exactly to human word segmentation in every v3 language.
- **Schema evolution:** Adding an optional nested array is backward-compatible for default output, but strict consumers may still need notice because enabled output has a new key.
- **No confidence at word level:** FluidAudio’s public `WordTiming` drops token confidences. Avoid duplicating upstream grouping solely to manufacture a word confidence in this iteration.
- **Testing models in CI:** Unit tests should use synthetic token timings. Full model inference should remain a local/manual integration check unless CI is intentionally configured to cache large models.
- **Combined output scope:** `process` always emits `transcript.json`, so do not duplicate all words into `combined.json` in this iteration. Consumers needing word detail should read the canonical transcript artifact.

## Open questions before implementation

1. Is nested `segments[].words[]` the preferred contract, or would a separate optional `words.json` artifact be more useful for downstream workflows?
2. Should timestamps be described as “approximate” in the flag help and schema documentation? This plan recommends yes.
3. Is a later word-to-speaker alignment feature anticipated? If so, retain stable word array ordering now, but do not add speaker fields yet.
4. Should the app eventually support subtitle exports (SRT/VTT)? This plan deliberately excludes them from the first implementation.
