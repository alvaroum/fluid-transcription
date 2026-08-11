import Foundation
import Testing

@testable import FluidTranscriptionCLI

@Suite("Transcript artifact encoding")
struct TranscriptArtifactEncodingTests {
    @Test("Transcript words encode stable snake-case timing fields")
    func transcriptWordEncoding() throws {
        let word = TranscriptWordArtifact(text: "Hello", startSec: 0.16, endSec: 0.48)

        let encoded = try JSONEncoder().encode(word)
        let root = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])

        #expect(root["text"] as? String == "Hello")
        #expect(root["start_sec"] as? Double == 0.16)
        #expect(root["end_sec"] as? Double == 0.48)
        #expect(root["startSec"] == nil)
        #expect(root["endSec"] == nil)
    }

    @Test("Requested word timings can be represented by an explicit empty array")
    func requestedButUnavailableWordTimingsEncodeAsEmptyArray() throws {
        let segment = TranscriptSegmentArtifact(
            segmentID: "seg-0001",
            startSec: nil,
            endSec: nil,
            text: "Example transcript",
            confidence: 0.93,
            words: []
        )

        let encoded = try JSONEncoder().encode(segment)
        let root = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let words = try #require(root["words"] as? [[String: Any]])

        #expect(words.isEmpty)
    }

    @Test("Default transcript segments do not contain word-level timing data")
    func defaultTranscriptOmitsWordTimings() throws {
        let segment = TranscriptSegmentArtifact(
            segmentID: "seg-0001",
            startSec: nil,
            endSec: nil,
            text: "Example transcript",
            confidence: 0.93
        )
        let transcript = TranscriptArtifact(
            schemaVersion: "1.0.0-draft",
            jobID: "job-001",
            input: "/tmp/example.wav",
            language: "auto",
            durationSec: nil,
            toolVersions: ToolVersions(appVersion: "test", fluidAudioVersion: "test"),
            segments: [segment],
            fullText: segment.text,
            notes: []
        )

        let encoded = try JSONEncoder().encode(transcript)
        let root = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let segments = try #require(root["segments"] as? [[String: Any]])
        let encodedSegment = try #require(segments.first)

        #expect(encodedSegment["words"] == nil)
        #expect(encodedSegment["start_sec"] == nil)
        #expect(encodedSegment["end_sec"] == nil)
    }
}
