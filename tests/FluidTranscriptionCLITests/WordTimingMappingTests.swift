import FluidAudio
import Testing

@testable import FluidTranscriptionCLI

@Suite("Word timing mapping")
struct WordTimingMappingTests {
    @Test("Subword token timings are grouped into chronological word artifacts")
    func groupsSubwordTokensIntoWords() {
        let tokenTimings = [
            token("▁Hello", start: 0.00, end: 0.08),
            token("▁wor", start: 0.16, end: 0.24),
            token("ld", start: 0.24, end: 0.32),
        ]

        let words = makeWordArtifacts(from: tokenTimings)

        #expect(words.map(\.text) == ["Hello", "world"])
        #expect(words.map(\.startSec) == [0.00, 0.16])
        #expect(words.map(\.endSec) == [0.08, 0.32])
    }

    @Test("Special tokens do not produce transcript words")
    func skipsSpecialTokens() {
        let tokenTimings = [
            token("▁Hello", start: 0.00, end: 0.08),
            token("<blank>", start: 0.08, end: 0.16),
            token("<pad>", start: 0.16, end: 0.24),
            token("▁world", start: 0.24, end: 0.32),
        ]

        let words = makeWordArtifacts(from: tokenTimings)

        #expect(words.map(\.text) == ["Hello", "world"])
    }

    @Test("Empty token timings produce no word artifacts")
    func emptyInputProducesNoWords() {
        #expect(makeWordArtifacts(from: []).isEmpty)
    }

    private func token(
        _ text: String,
        start: Double,
        end: Double,
        confidence: Float = 1.0
    ) -> TokenTiming {
        TokenTiming(
            token: text,
            tokenId: 0,
            startTime: start,
            endTime: end,
            confidence: confidence
        )
    }
}
