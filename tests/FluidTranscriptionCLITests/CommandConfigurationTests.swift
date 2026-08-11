import ArgumentParser
import Testing

@testable import FluidTranscriptionCLI

@Suite("Command configuration")
struct CommandConfigurationTests {
    @Test("Transcribe word timestamps are opt-in")
    func transcribeWordTimestampsAreOptIn() throws {
        let defaultCommand = try TranscribeCommand.parse([
            "--input", "/tmp/example.wav",
            "--output", "/tmp/runs",
        ])
        let timedCommand = try TranscribeCommand.parse([
            "--input", "/tmp/example.wav",
            "--output", "/tmp/runs",
            "--model-version", "v2",
            "--word-timestamps",
        ])

        #expect(!defaultCommand.transcript.wordTimestamps)
        #expect(defaultCommand.transcript.modelVersion == .v3)
        #expect(timedCommand.transcript.wordTimestamps)
        #expect(timedCommand.transcript.modelVersion == .v2)
    }

    @Test("Process word timestamps are opt-in")
    func processWordTimestampsAreOptIn() throws {
        let defaultCommand = try ProcessCommand.parse([
            "--input", "/tmp/example.wav",
            "--output", "/tmp/runs",
        ])
        let timedCommand = try ProcessCommand.parse([
            "--input", "/tmp/example.wav",
            "--output", "/tmp/runs",
            "--word-timestamps",
        ])

        #expect(!defaultCommand.transcript.wordTimestamps)
        #expect(timedCommand.transcript.wordTimestamps)
    }
}
