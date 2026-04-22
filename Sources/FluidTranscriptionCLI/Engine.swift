import FluidAudio
import Foundation

enum TranscriptModelVersion: String, Codable, CaseIterable {
    case v2
    case v3

    var fluidAudioValue: AsrModelVersion {
        switch self {
        case .v2:
            return .v2
        case .v3:
            return .v3
        }
    }
}

struct FluidTranscriptionEngine {
    func transcribe(inputURL: URL, modelVersion: TranscriptModelVersion) async throws -> TranscriptArtifact {
        let models = try await AsrModels.downloadAndLoad(version: modelVersion.fluidAudioValue)
        let manager = AsrManager()
        try await manager.loadModels(models)
        let result = try await manager.transcribe(inputURL, source: .system)

        return TranscriptArtifact(
            schemaVersion: AppConstants.schemaVersion,
            jobID: "",
            input: inputURL.path,
            language: modelVersion == .v2 ? "en" : "auto",
            durationSec: nil,
            toolVersions: ToolVersions(appVersion: AppConstants.appVersion, fluidAudioVersion: AppConstants.fluidAudioVersion),
            segments: [
                TranscriptSegmentArtifact(
                    segmentID: "seg-0001",
                    startSec: nil,
                    endSec: nil,
                    text: result.text,
                    confidence: Double(result.confidence)
                )
            ],
            fullText: result.text,
            notes: [
                "ASR models are downloaded automatically on first use and cached by FluidAudio.",
                "Initial Swift CLI integration emits a single transcript segment until richer ASR timing extraction is added."
            ]
        )
    }

    func diarize(inputURL: URL) async throws -> DiarizationArtifact {
        let manager = OfflineDiarizerManager()
        try await manager.prepareModels()
        let result = try await manager.process(inputURL)
        let turns = result.segments.enumerated().map { index, segment in
            SpeakerTurnArtifact(
                turnID: String(format: "turn-%04d", index + 1),
                speakerID: segment.speakerId,
                startSec: Double(segment.startTimeSeconds),
                endSec: Double(segment.endTimeSeconds)
            )
        }
        let groupedTurns = Dictionary(grouping: turns) { turn in turn.speakerID }
        let speakers = groupedTurns
            .map { speakerID, speakerTurns in
                let duration = speakerTurns.reduce(0.0) { partial, turn in
                    partial + max(0, turn.endSec - turn.startSec)
                }
                return SpeakerSummaryArtifact(speakerID: speakerID, totalTalkSec: duration)
            }
            .sorted { $0.speakerID < $1.speakerID }
        let durationSec = turns.map { $0.endSec }.max()

        return DiarizationArtifact(
            schemaVersion: AppConstants.schemaVersion,
            jobID: "",
            input: inputURL.path,
            durationSec: durationSec,
            toolVersions: ToolVersions(appVersion: AppConstants.appVersion, fluidAudioVersion: AppConstants.fluidAudioVersion),
            speakers: speakers,
            turns: turns
        )
    }
}
