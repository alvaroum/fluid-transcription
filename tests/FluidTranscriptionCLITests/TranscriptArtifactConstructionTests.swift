import FluidAudio
import Foundation
import Testing

@testable import FluidTranscriptionCLI

@Suite("Transcript artifact construction")
struct TranscriptArtifactConstructionTests {
    @Test("Requested word timestamps populate words and coarse segment bounds")
    func requestedWordTimestampsPopulateSegment() throws {
        let result = ASRResult(
            text: "Hello world",
            confidence: 0.93,
            duration: 1.5,
            processingTime: 0.1,
            tokenTimings: [
                token("▁Hello", start: 0.0, end: 0.4),
                token("▁wor", start: 0.6, end: 0.8),
                token("ld", start: 0.8, end: 1.1),
            ]
        )

        let artifact = makeTranscriptArtifact(
            inputURL: URL(fileURLWithPath: "/tmp/example.wav"),
            modelVersion: .v3,
            result: result,
            includeWordTimestamps: true
        )
        let segment = try #require(artifact.segments.first)
        let words = try #require(segment.words)

        #expect(words.map(\.text) == ["Hello", "world"])
        #expect(segment.startSec == 0.0)
        #expect(segment.endSec == 1.1)
        #expect(artifact.notes.contains { $0.contains("approximate decoder-derived") })
    }

    @Test("Requested but unavailable word timestamps remain explicit and honest")
    func unavailableWordTimestampsProduceEmptyWordsAndNote() throws {
        let result = ASRResult(
            text: "Hello world",
            confidence: 0.93,
            duration: 1.5,
            processingTime: 0.1,
            tokenTimings: nil
        )

        let artifact = makeTranscriptArtifact(
            inputURL: URL(fileURLWithPath: "/tmp/example.wav"),
            modelVersion: .v3,
            result: result,
            includeWordTimestamps: true
        )
        let segment = try #require(artifact.segments.first)
        let words = try #require(segment.words)

        #expect(words.isEmpty)
        #expect(segment.startSec == nil)
        #expect(segment.endSec == nil)
        #expect(artifact.notes.contains { $0.contains("requested") && $0.contains("unavailable") })
    }

    @Test("Default construction omits detailed word timings")
    func defaultConstructionOmitsWordTimings() throws {
        let result = ASRResult(
            text: "Hello world",
            confidence: 0.93,
            duration: 1.5,
            processingTime: 0.1,
            tokenTimings: [
                token("▁Hello", start: 0.0, end: 0.4),
                token("▁world", start: 0.6, end: 1.1),
            ]
        )

        let artifact = makeTranscriptArtifact(
            inputURL: URL(fileURLWithPath: "/tmp/example.wav"),
            modelVersion: .v3,
            result: result,
            includeWordTimestamps: false
        )
        let segment = try #require(artifact.segments.first)

        #expect(artifact.durationSec == 1.5)
        #expect(segment.words == nil)
        #expect(segment.startSec == nil)
        #expect(segment.endSec == nil)
        #expect(!artifact.notes.contains { $0.contains("approximate") || $0.contains("unavailable") })
    }

    private func token(_ text: String, start: Double, end: Double) -> TokenTiming {
        TokenTiming(
            token: text,
            tokenId: 0,
            startTime: start,
            endTime: end,
            confidence: 1.0
        )
    }
}
