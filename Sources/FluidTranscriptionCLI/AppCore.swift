import CryptoKit
import Foundation

enum AppConstants {
    static let appName = "fluid-transcription"
    static let appVersion = "202604.3"
    static let schemaVersion = "1.0.0-draft"
    static let fluidAudioVersion = "0.13.6"
}

enum RunMode: String, Codable {
    case transcribe
    case diarize
    case process
}

struct JobContext {
    let jobID: String
    let inputURL: URL
    let runDirectoryURL: URL
    let createdAt: String
    let mode: RunMode
}

struct EventRecord: Codable {
    let timestamp: String
    let event: String
    let details: [String: String]
}

struct ToolVersions: Codable {
    let appVersion: String
    let fluidAudioVersion: String
}

struct RunArtifact: Codable {
    let schemaVersion: String
    let jobID: String
    let mode: String
    let input: String
    let runDirectory: String
    let createdAt: String
    let status: String
    let artifacts: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case jobID = "job_id"
        case mode
        case input
        case runDirectory = "run_dir"
        case createdAt = "created_at"
        case status
        case artifacts
    }
}

struct TranscriptSegmentArtifact: Codable {
    let segmentID: String
    let startSec: Double?
    let endSec: Double?
    let text: String
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case segmentID = "segment_id"
        case startSec = "start_sec"
        case endSec = "end_sec"
        case text
        case confidence
    }
}

struct TranscriptArtifact: Codable {
    let schemaVersion: String
    let jobID: String
    let input: String
    let language: String
    let durationSec: Double?
    let toolVersions: ToolVersions
    let segments: [TranscriptSegmentArtifact]
    let fullText: String
    let notes: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case jobID = "job_id"
        case input
        case language
        case durationSec = "duration_sec"
        case toolVersions = "tool_versions"
        case segments
        case fullText = "full_text"
        case notes
    }
}

struct SpeakerSummaryArtifact: Codable {
    let speakerID: String
    let totalTalkSec: Double

    enum CodingKeys: String, CodingKey {
        case speakerID = "speaker_id"
        case totalTalkSec = "total_talk_sec"
    }
}

struct SpeakerTurnArtifact: Codable {
    let turnID: String
    let speakerID: String
    let startSec: Double
    let endSec: Double

    enum CodingKeys: String, CodingKey {
        case turnID = "turn_id"
        case speakerID = "speaker_id"
        case startSec = "start_sec"
        case endSec = "end_sec"
    }
}

struct DiarizationArtifact: Codable {
    let schemaVersion: String
    let jobID: String
    let input: String
    let durationSec: Double?
    let toolVersions: ToolVersions
    let speakers: [SpeakerSummaryArtifact]
    let turns: [SpeakerTurnArtifact]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case jobID = "job_id"
        case input
        case durationSec = "duration_sec"
        case toolVersions = "tool_versions"
        case speakers
        case turns
    }
}

struct CombinedSummaryArtifact: Codable {
    let durationSec: Double?
    let speakerCount: Int
    let segmentCount: Int

    enum CodingKeys: String, CodingKey {
        case durationSec = "duration_sec"
        case speakerCount = "speaker_count"
        case segmentCount = "segment_count"
    }
}

struct CombinedArtifact: Codable {
    let schemaVersion: String
    let jobID: String
    let input: String
    let toolVersions: ToolVersions
    let summary: CombinedSummaryArtifact
    let transcriptFullText: String
    let speakerTurns: [SpeakerTurnArtifact]
    let notes: [String]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case jobID = "job_id"
        case input
        case toolVersions = "tool_versions"
        case summary
        case transcriptFullText = "transcript_full_text"
        case speakerTurns = "speaker_turns"
        case notes
    }
}

struct VersionArtifact: Codable {
    let app: String
    let appVersion: String
    let schemaVersion: String
    let fluidAudioVersion: String
    let models: String

    enum CodingKeys: String, CodingKey {
        case app
        case appVersion = "app_version"
        case schemaVersion = "schema_version"
        case fluidAudioVersion = "fluidaudio_version"
        case models
    }
}

struct ValidationReport: Codable {
    let ok: Bool
    let errors: [String]
    let warnings: [String]
}

enum AppError: LocalizedError {
    case invalidInput(String)
    case outputExists(String)
    case validationFailed([String])
    case inputPreparationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .invalidInput(message):
            return message
        case let .outputExists(message):
            return message
        case let .validationFailed(errors):
            return errors.joined(separator: "\n")
        case let .inputPreparationFailed(message):
            return message
        }
    }
}

func makeJobContext(inputPath: String, outputPath: String, jobID: String?, overwrite: Bool, mode: RunMode) throws -> JobContext {
    let inputURL = URL(fileURLWithPath: NSString(string: inputPath).expandingTildeInPath).standardizedFileURL
    guard FileManager.default.fileExists(atPath: inputURL.path) else {
        throw AppError.invalidInput("Input media not found: \(inputURL.path)")
    }

    let outputURL = URL(fileURLWithPath: NSString(string: outputPath).expandingTildeInPath, isDirectory: true).standardizedFileURL
    let resolvedJobID = jobID ?? makeJobID(for: inputURL)
    let runDirectoryURL = outputURL.appendingPathComponent(resolvedJobID, isDirectory: true)

    if FileManager.default.fileExists(atPath: runDirectoryURL.path) {
        guard overwrite else {
            throw AppError.outputExists("Output directory already exists: \(runDirectoryURL.path)")
        }
        try FileManager.default.removeItem(at: runDirectoryURL)
    }

    try FileManager.default.createDirectory(at: runDirectoryURL, withIntermediateDirectories: true)
    return JobContext(
        jobID: resolvedJobID,
        inputURL: inputURL,
        runDirectoryURL: runDirectoryURL,
        createdAt: timestampNow(),
        mode: mode
    )
}

func makeJobID(for inputURL: URL) -> String {
    let values = try? inputURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
    let fileSize = values?.fileSize ?? 0
    let modifiedAt = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
    let digestInput = "\(inputURL.path)|\(fileSize)|\(Int(modifiedAt))"
    let digest = SHA256.hash(data: Data(digestInput.utf8)).map { String(format: "%02x", $0) }.joined()
    let slug = inputURL.deletingPathExtension().lastPathComponent
        .lowercased()
        .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return "\(slug.isEmpty ? "job" : slug)-\(digest.prefix(12))"
}

func timestampNow() -> String {
    ISO8601DateFormatter().string(from: Date())
}

func writeJSON<T: Encodable>(_ value: T, to url: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    try data.write(to: url)
}

func writeJSONL(_ records: [EventRecord], to url: URL) throws {
    let encoder = JSONEncoder()
    let lines = try records.map { record -> String in
        let data = try encoder.encode(record)
        guard let line = String(data: data, encoding: .utf8) else {
            throw AppError.invalidInput("Failed to encode events JSONL")
        }
        return line
    }
    try lines.joined(separator: "\n").appending("\n").write(to: url, atomically: true, encoding: .utf8)
}

func writeText(_ text: String, to url: URL) throws {
    try text.write(to: url, atomically: true, encoding: .utf8)
}

func makeCombinedArtifact(transcript: TranscriptArtifact, diarization: DiarizationArtifact) -> CombinedArtifact {
    CombinedArtifact(
        schemaVersion: AppConstants.schemaVersion,
        jobID: transcript.jobID,
        input: transcript.input,
        toolVersions: ToolVersions(appVersion: AppConstants.appVersion, fluidAudioVersion: AppConstants.fluidAudioVersion),
        summary: CombinedSummaryArtifact(
            durationSec: diarization.durationSec,
            speakerCount: diarization.speakers.count,
            segmentCount: transcript.segments.count
        ),
        transcriptFullText: transcript.fullText,
        speakerTurns: diarization.turns,
        notes: [
            "The `process` command runs transcription and diarization in one pass at the app level.",
            "Transcript-to-speaker alignment is deferred until timestamp-rich ASR segmentation is added."
        ]
    )
}

func makeCombinedMarkdown(transcript: TranscriptArtifact, diarization: DiarizationArtifact) -> String {
    var sections: [String] = []
    sections.append("# Fluid Transcription \(transcript.jobID)")
    sections.append("")
    sections.append("## Transcript")
    sections.append(transcript.fullText)
    sections.append("")
    sections.append("## Speaker Turns")
    if diarization.turns.isEmpty {
        sections.append("No speaker turns detected.")
    } else {
        for turn in diarization.turns {
            let startText = String(format: "%.2f", turn.startSec)
            let endText = String(format: "%.2f", turn.endSec)
            sections.append("- \(turn.speakerID) [\(startText)s - \(endText)s]")
        }
    }
    sections.append("")
    return sections.joined(separator: "\n")
}

func validateRunDirectory(_ runDirectoryURL: URL) throws -> ValidationReport {
    var errors: [String] = []
    var warnings: [String] = []

    let runURL = runDirectoryURL.appendingPathComponent("run.json")
    guard FileManager.default.fileExists(atPath: runURL.path) else {
        return ValidationReport(ok: false, errors: ["Missing run.json"], warnings: [])
    }

    let runData = try Data(contentsOf: runURL)
    let runRecord = try JSONDecoder().decode(RunArtifact.self, from: runData)

    for artifact in runRecord.artifacts {
        let artifactURL = runDirectoryURL.appendingPathComponent(artifact)
        guard FileManager.default.fileExists(atPath: artifactURL.path) else {
            errors.append("Missing artifact referenced by run.json: \(artifact)")
            continue
        }

        if artifact == "events.jsonl" {
            let lines = try String(contentsOf: artifactURL, encoding: .utf8)
                .split(separator: "\n")
                .map(String.init)
            if lines.isEmpty {
                warnings.append("events.jsonl is empty")
            }
            for (index, line) in lines.enumerated() {
                guard let data = line.data(using: .utf8) else {
                    errors.append("events.jsonl line \(index + 1) is not valid UTF-8")
                    continue
                }
                do {
                    _ = try JSONDecoder().decode(EventRecord.self, from: data)
                } catch {
                    errors.append("events.jsonl line \(index + 1) is invalid JSON")
                }
            }
            continue
        }

        let data = try Data(contentsOf: artifactURL)
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
            errors.append("Artifact is not valid JSON: \(artifact)")
            continue
        }
    }

    return ValidationReport(ok: errors.isEmpty, errors: errors, warnings: warnings)
}
