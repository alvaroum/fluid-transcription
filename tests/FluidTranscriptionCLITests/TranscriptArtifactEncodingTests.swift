import Foundation
import Testing

@testable import FluidTranscriptionCLI

@Suite("Transcript artifact encoding")
struct TranscriptArtifactEncodingTests {
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
