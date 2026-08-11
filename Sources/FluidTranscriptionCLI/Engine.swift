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

func makeWordArtifacts(from tokenTimings: [TokenTiming]) -> [TranscriptWordArtifact] {
    buildWordTimings(from: tokenTimings).map { timing in
        TranscriptWordArtifact(
            text: timing.word,
            startSec: timing.startTime,
            endSec: timing.endTime
        )
    }
}

func makeTranscriptArtifact(
    inputURL: URL,
    modelVersion: TranscriptModelVersion,
    result: ASRResult,
    includeWordTimestamps: Bool
) -> TranscriptArtifact {
    let words = includeWordTimestamps
        ? makeWordArtifacts(from: result.tokenTimings ?? [])
        : nil
    var notes = [
        "ASR models are downloaded automatically on first use and cached by FluidAudio.",
        "The transcript currently contains one coarse segment."
    ]
    if let words, !words.isEmpty {
        notes.append("Word timestamps are approximate decoder-derived timings aggregated from FluidAudio token timings.")
    } else if includeWordTimestamps {
        notes.append("Word timestamps were requested but unavailable because FluidAudio returned no usable token timings.")
    }

    return TranscriptArtifact(
        schemaVersion: AppConstants.schemaVersion,
        jobID: "",
        input: inputURL.path,
        language: modelVersion == .v2 ? "en" : "auto",
        durationSec: result.duration,
        toolVersions: ToolVersions(appVersion: AppConstants.appVersion, fluidAudioVersion: AppConstants.fluidAudioVersion),
        segments: [
            TranscriptSegmentArtifact(
                segmentID: "seg-0001",
                startSec: words?.first?.startSec,
                endSec: words?.last?.endSec,
                text: result.text,
                confidence: Double(result.confidence),
                words: words
            )
        ],
        fullText: result.text,
        notes: notes
    )
}

struct FluidTranscriptionEngine {
    func transcribe(
        inputURL: URL,
        modelVersion: TranscriptModelVersion,
        includeWordTimestamps: Bool = false
    ) async throws -> TranscriptArtifact {
        let models = try await AsrModels.downloadAndLoad(version: modelVersion.fluidAudioValue)
        let manager = AsrManager()
        try await manager.loadModels(models)
        var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(inputURL, decoderState: &decoderState)

        return makeTranscriptArtifact(
            inputURL: inputURL,
            modelVersion: modelVersion,
            result: result,
            includeWordTimestamps: includeWordTimestamps
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
