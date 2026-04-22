import ArgumentParser
import Dispatch
import Foundation

struct FluidTranscriptionCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: AppConstants.appName,
        abstract: "macOS CLI for transcription and speaker diarization built directly on FluidAudio.",
        subcommands: [VersionCommand.self, TranscribeCommand.self, DiarizeCommand.self, ProcessCommand.self, ValidateCommand.self]
    )
}

struct CommonRunOptions: ParsableArguments {
    @Option(help: "Path to the input audio or video file.")
    var input: String

    @Option(help: "Directory where the run folder should be created.")
    var output: String

    @Option(name: .customLong("job-id"), help: "Optional explicit job identifier.")
    var jobID: String?

    @Flag(help: "Overwrite an existing run directory if it already exists.")
    var overwrite = false
}

enum TranscriptModelArgument: String, ExpressibleByArgument {
    case v2
    case v3

    var engineValue: TranscriptModelVersion {
        switch self {
        case .v2:
            return .v2
        case .v3:
            return .v3
        }
    }
}

struct VersionCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "version", abstract: "Print app and FluidAudio version information.")

    mutating func run() throws {
        let payload = VersionArtifact(
            app: AppConstants.appName,
            appVersion: AppConstants.appVersion,
            schemaVersion: AppConstants.schemaVersion,
            fluidAudioVersion: AppConstants.fluidAudioVersion,
            models: "Downloaded automatically by FluidAudio on install-time usage or first run."
        )
        try writeJSON(payload, to: FileHandle.standardOutput)
    }
}

struct TranscribeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "transcribe", abstract: "Transcribe an input file with FluidAudio ASR.")

    @OptionGroup var common: CommonRunOptions
    @Option(name: .customLong("model-version"), help: "ASR model version to use: v2 for English-only, v3 for multilingual.")
    var modelVersion: TranscriptModelArgument = .v3

    mutating func run() throws {
        let input = common.input
        let output = common.output
        let jobID = common.jobID
        let overwrite = common.overwrite
        let selectedModel = modelVersion.engineValue

        try runBlocking {
            let context = try makeJobContext(inputPath: input, outputPath: output, jobID: jobID, overwrite: overwrite, mode: .transcribe)
            let engine = FluidTranscriptionEngine()
            var events = [EventRecord(timestamp: timestampNow(), event: "job_started", details: ["mode": RunMode.transcribe.rawValue])]

            do {
                var transcript = try await engine.transcribe(inputURL: context.inputURL, modelVersion: selectedModel)
                transcript = TranscriptArtifact(
                    schemaVersion: transcript.schemaVersion,
                    jobID: context.jobID,
                    input: transcript.input,
                    language: transcript.language,
                    durationSec: transcript.durationSec,
                    toolVersions: transcript.toolVersions,
                    segments: transcript.segments,
                    fullText: transcript.fullText,
                    notes: transcript.notes
                )
                try writeJSON(transcript, to: context.runDirectoryURL.appendingPathComponent("transcript.json"))
                events.append(EventRecord(timestamp: timestampNow(), event: "artifact_written", details: ["artifact": "transcript.json"]))
                try finalizeRun(context: context, artifacts: ["transcript.json", "events.jsonl"], events: events)
            } catch {
                try failRun(context: context, events: events, error: error)
                throw error
            }
        }
    }
}

struct DiarizeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "diarize", abstract: "Run offline speaker diarization on an input file.")

    @OptionGroup var common: CommonRunOptions

    mutating func run() throws {
        let input = common.input
        let output = common.output
        let jobID = common.jobID
        let overwrite = common.overwrite

        try runBlocking {
            let context = try makeJobContext(inputPath: input, outputPath: output, jobID: jobID, overwrite: overwrite, mode: .diarize)
            let engine = FluidTranscriptionEngine()
            var events = [EventRecord(timestamp: timestampNow(), event: "job_started", details: ["mode": RunMode.diarize.rawValue])]

            do {
                var diarization = try await engine.diarize(inputURL: context.inputURL)
                diarization = DiarizationArtifact(
                    schemaVersion: diarization.schemaVersion,
                    jobID: context.jobID,
                    input: diarization.input,
                    durationSec: diarization.durationSec,
                    toolVersions: diarization.toolVersions,
                    speakers: diarization.speakers,
                    turns: diarization.turns
                )
                try writeJSON(diarization, to: context.runDirectoryURL.appendingPathComponent("diarization.json"))
                events.append(EventRecord(timestamp: timestampNow(), event: "artifact_written", details: ["artifact": "diarization.json"]))
                try finalizeRun(context: context, artifacts: ["diarization.json", "events.jsonl"], events: events)
            } catch {
                try failRun(context: context, events: events, error: error)
                throw error
            }
        }
    }
}

struct ProcessCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "process", abstract: "Transcribe and diarize the input in one command.")

    @OptionGroup var common: CommonRunOptions
    @Option(name: .customLong("model-version"), help: "ASR model version to use: v2 for English-only, v3 for multilingual.")
    var modelVersion: TranscriptModelArgument = .v3

    mutating func run() throws {
        let input = common.input
        let output = common.output
        let jobID = common.jobID
        let overwrite = common.overwrite
        let selectedModel = modelVersion.engineValue

        try runBlocking {
            let context = try makeJobContext(inputPath: input, outputPath: output, jobID: jobID, overwrite: overwrite, mode: .process)
            let engine = FluidTranscriptionEngine()
            var events = [EventRecord(timestamp: timestampNow(), event: "job_started", details: ["mode": RunMode.process.rawValue])]

            do {
                var transcript = try await engine.transcribe(inputURL: context.inputURL, modelVersion: selectedModel)
                transcript = TranscriptArtifact(
                    schemaVersion: transcript.schemaVersion,
                    jobID: context.jobID,
                    input: transcript.input,
                    language: transcript.language,
                    durationSec: transcript.durationSec,
                    toolVersions: transcript.toolVersions,
                    segments: transcript.segments,
                    fullText: transcript.fullText,
                    notes: transcript.notes
                )
                var diarization = try await engine.diarize(inputURL: context.inputURL)
                diarization = DiarizationArtifact(
                    schemaVersion: diarization.schemaVersion,
                    jobID: context.jobID,
                    input: diarization.input,
                    durationSec: diarization.durationSec,
                    toolVersions: diarization.toolVersions,
                    speakers: diarization.speakers,
                    turns: diarization.turns
                )
                let combined = makeCombinedArtifact(transcript: transcript, diarization: diarization)
                let markdown = makeCombinedMarkdown(transcript: transcript, diarization: diarization)

                try writeJSON(transcript, to: context.runDirectoryURL.appendingPathComponent("transcript.json"))
                try writeJSON(diarization, to: context.runDirectoryURL.appendingPathComponent("diarization.json"))
                try writeJSON(combined, to: context.runDirectoryURL.appendingPathComponent("combined.json"))
                try writeText(markdown, to: context.runDirectoryURL.appendingPathComponent("combined.md"))
                events.append(EventRecord(timestamp: timestampNow(), event: "artifact_written", details: ["artifact": "transcript.json"]))
                events.append(EventRecord(timestamp: timestampNow(), event: "artifact_written", details: ["artifact": "diarization.json"]))
                events.append(EventRecord(timestamp: timestampNow(), event: "artifact_written", details: ["artifact": "combined.json"]))

                try finalizeRun(context: context, artifacts: ["transcript.json", "diarization.json", "combined.json", "events.jsonl"], events: events)
            } catch {
                try failRun(context: context, events: events, error: error)
                throw error
            }
        }
    }
}

struct ValidateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "validate", abstract: "Validate a previously generated run directory.")

    @Option(name: .customLong("run-dir"), help: "Path to the run directory produced by the app.")
    var runDirectory: String

    mutating func run() throws {
        let url = URL(fileURLWithPath: NSString(string: runDirectory).expandingTildeInPath, isDirectory: true).standardizedFileURL
        let report = try validateRunDirectory(url)
        try writeJSON(report, to: FileHandle.standardOutput)
        if !report.ok {
            throw AppError.validationFailed(report.errors)
        }
    }
}

func finalizeRun(context: JobContext, artifacts: [String], events: [EventRecord]) throws {
    var updatedEvents = events
    updatedEvents.append(EventRecord(timestamp: timestampNow(), event: "job_completed", details: ["status": "completed"]))
    try writeJSONL(updatedEvents, to: context.runDirectoryURL.appendingPathComponent("events.jsonl"))
    let runArtifact = RunArtifact(
        schemaVersion: AppConstants.schemaVersion,
        jobID: context.jobID,
        mode: context.mode.rawValue,
        input: context.inputURL.path,
        runDirectory: context.runDirectoryURL.path,
        createdAt: context.createdAt,
        status: "completed",
        artifacts: artifacts
    )
    try writeJSON(runArtifact, to: context.runDirectoryURL.appendingPathComponent("run.json"))
    try writeJSON(runArtifact, to: FileHandle.standardOutput)
}

func failRun(context: JobContext, events: [EventRecord], error: Error) throws {
    var updatedEvents = events
    updatedEvents.append(EventRecord(timestamp: timestampNow(), event: "job_failed", details: ["error": error.localizedDescription]))
    try writeJSONL(updatedEvents, to: context.runDirectoryURL.appendingPathComponent("events.jsonl"))
    let runArtifact = RunArtifact(
        schemaVersion: AppConstants.schemaVersion,
        jobID: context.jobID,
        mode: context.mode.rawValue,
        input: context.inputURL.path,
        runDirectory: context.runDirectoryURL.path,
        createdAt: context.createdAt,
        status: "failed",
        artifacts: ["events.jsonl"]
    )
    try writeJSON(runArtifact, to: context.runDirectoryURL.appendingPathComponent("run.json"))
}

extension Encodable {
    fileprivate func writeToStdout() throws {
        try writeJSON(self, to: FileHandle.standardOutput)
    }
}

func writeJSON<T: Encodable>(_ value: T, to handle: FileHandle) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    handle.write(data)
    handle.write(Data("\n".utf8))
}

final class BlockingResultBox: @unchecked Sendable {
    var outcome: Result<Void, Error>?
}

func runBlocking(_ operation: @Sendable @escaping () async throws -> Void) throws {
    let semaphore = DispatchSemaphore(value: 0)
    let resultBox = BlockingResultBox()

    Task.detached(priority: .userInitiated) {
        do {
            try await operation()
            resultBox.outcome = .success(())
        } catch {
            resultBox.outcome = .failure(error)
        }
        semaphore.signal()
    }

    semaphore.wait()
    switch resultBox.outcome {
    case let .success(value):
        return value
    case let .failure(error):
        throw error
    case .none:
        throw ValidationError("Unexpected missing command result")
    }
}

FluidTranscriptionCLI.main()
