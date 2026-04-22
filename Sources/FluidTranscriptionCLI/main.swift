import ArgumentParser
import Dispatch
import Foundation

struct FluidTranscriptionCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
    commandName: AppConstants.commandName,
                abstract: "Native macOS CLI for transcription, speaker diarization, and combined processing.",
                discussion: """
                Capabilities:
                    - `transcribe`: speech-to-text only
                    - `diarize`: speaker diarization only
                    - `process`: transcription plus diarization in one run
                    - `validate`: schema validation for a generated run directory

                Input handling:
                    - Accepts audio or video files.
                    - Automatically normalizes fragile or compressed inputs to an internal PCM WAV when needed.
                    - Uses native AVFoundation decoding first and falls back to ffmpeg when available.

                Output model:
                    - Machine-readable JSON artifacts for AI agents
                    - Optional Markdown summary artifact for combined runs
                    - Deterministic run directories under the output folder

                Typical use:
                    ft process --input meeting.m4a --output ./runs

                Compatibility:
                    - The installed packages also provide `fluid-transcription` as a compatibility alias.
                """,
        subcommands: [VersionCommand.self, TranscribeCommand.self, DiarizeCommand.self, ProcessCommand.self, ValidateCommand.self]
    )
}

struct CommonRunOptions: ParsableArguments {
        @Option(help: "Path to the input audio or video file. Compressed inputs are normalized automatically before processing when needed.")
    var input: String

        @Option(help: "Directory where the run folder and output artifacts should be created.")
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
    static let configuration = CommandConfiguration(
        commandName: "version",
        abstract: "Print app, schema, and FluidAudio version information.",
        discussion: "Emits a compact JSON object describing the CLI version, schema version, and FluidAudio version used by the current build."
    )

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
    static let configuration = CommandConfiguration(
        commandName: "transcribe",
        abstract: "Transcribe an input file to JSON text artifacts.",
        discussion: """
        Produces a run directory containing:
          - `run.json`
          - `events.jsonl`
          - `transcript.json`

        Use this when you need speech-to-text only.
        """
    )

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
            let preparedInput = try InputPreparation.prepareForSynchronousCLI(url: context.inputURL)
            defer { preparedInput.cleanup() }
            let engine = FluidTranscriptionEngine()
            var events = [EventRecord(timestamp: timestampNow(), event: "job_started", details: ["mode": RunMode.transcribe.rawValue])]
            if let strategy = preparedInput.normalizationStrategy {
                events.append(EventRecord(timestamp: timestampNow(), event: "input_prepared", details: ["strategy": strategy]))
            }

            do {
                var transcript = try await engine.transcribe(inputURL: preparedInput.processingURL, modelVersion: selectedModel)
                transcript = TranscriptArtifact(
                    schemaVersion: transcript.schemaVersion,
                    jobID: context.jobID,
                    input: context.inputURL.path,
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
    static let configuration = CommandConfiguration(
        commandName: "diarize",
        abstract: "Detect speaker turns and speaker totals for an input file.",
        discussion: """
        Produces a run directory containing:
          - `run.json`
          - `events.jsonl`
          - `diarization.json`

        Use this when you need speaker timing without transcript text.
        """
    )

    @OptionGroup var common: CommonRunOptions

    mutating func run() throws {
        let input = common.input
        let output = common.output
        let jobID = common.jobID
        let overwrite = common.overwrite

        try runBlocking {
            let context = try makeJobContext(inputPath: input, outputPath: output, jobID: jobID, overwrite: overwrite, mode: .diarize)
            let preparedInput = try InputPreparation.prepareForSynchronousCLI(url: context.inputURL)
            defer { preparedInput.cleanup() }
            let engine = FluidTranscriptionEngine()
            var events = [EventRecord(timestamp: timestampNow(), event: "job_started", details: ["mode": RunMode.diarize.rawValue])]
            if let strategy = preparedInput.normalizationStrategy {
                events.append(EventRecord(timestamp: timestampNow(), event: "input_prepared", details: ["strategy": strategy]))
            }

            do {
                var diarization = try await engine.diarize(inputURL: preparedInput.processingURL)
                diarization = DiarizationArtifact(
                    schemaVersion: diarization.schemaVersion,
                    jobID: context.jobID,
                    input: context.inputURL.path,
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
    static let configuration = CommandConfiguration(
        commandName: "process",
        abstract: "Run transcription and diarization together in one command.",
        discussion: """
        Produces a run directory containing:
          - `run.json`
          - `events.jsonl`
          - `transcript.json`
          - `diarization.json`
          - `combined.json`
          - `combined.md`

        This is the main end-to-end command for AI-agent workflows.
        It accepts original media files directly and normalizes them automatically before model execution when required.
        """
    )

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
            let preparedInput = try InputPreparation.prepareForSynchronousCLI(url: context.inputURL)
            defer { preparedInput.cleanup() }
            let engine = FluidTranscriptionEngine()
            var events = [EventRecord(timestamp: timestampNow(), event: "job_started", details: ["mode": RunMode.process.rawValue])]
            if let strategy = preparedInput.normalizationStrategy {
                events.append(EventRecord(timestamp: timestampNow(), event: "input_prepared", details: ["strategy": strategy]))
            }

            do {
                var transcript = try await engine.transcribe(inputURL: preparedInput.processingURL, modelVersion: selectedModel)
                transcript = TranscriptArtifact(
                    schemaVersion: transcript.schemaVersion,
                    jobID: context.jobID,
                    input: context.inputURL.path,
                    language: transcript.language,
                    durationSec: transcript.durationSec,
                    toolVersions: transcript.toolVersions,
                    segments: transcript.segments,
                    fullText: transcript.fullText,
                    notes: transcript.notes
                )
                var diarization = try await engine.diarize(inputURL: preparedInput.processingURL)
                diarization = DiarizationArtifact(
                    schemaVersion: diarization.schemaVersion,
                    jobID: context.jobID,
                    input: context.inputURL.path,
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
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate a previously generated run directory.",
        discussion: "Checks that expected artifacts exist and that the run directory conforms to the CLI output contract."
    )

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
