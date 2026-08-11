import AVFoundation
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

func makeWordArtifacts(
    from tokenTimings: [TokenTiming],
    audioDurationSec: Double? = nil
) -> [TranscriptWordArtifact] {
    let durationLimit = audioDurationSec.flatMap { duration in
        duration.isFinite && duration > 0 ? duration : nil
    }
    var lastStartSec = -Double.infinity
    var artifacts: [TranscriptWordArtifact] = []

    for timing in buildWordTimings(from: tokenTimings) {
        guard timing.startTime.isFinite, timing.endTime.isFinite else {
            continue
        }
        let startSec = min(max(0, timing.startTime), durationLimit ?? .infinity)
        let endSec = min(max(0, timing.endTime), durationLimit ?? .infinity)
        guard endSec > startSec, startSec >= lastStartSec else {
            continue
        }
        artifacts.append(
            TranscriptWordArtifact(
                text: timing.word,
                startSec: startSec,
                endSec: endSec
            )
        )
        lastStartSec = startSec
    }

    return artifacts
}

func makeTranscriptArtifact(
    inputURL: URL,
    modelVersion: TranscriptModelVersion,
    result: ASRResult,
    audioDurationSec: Double? = nil,
    includeWordTimestamps: Bool
) -> TranscriptArtifact {
    let durationSec = audioDurationSec ?? (result.duration > 0 ? result.duration : nil)
    let words = includeWordTimestamps
        ? makeWordArtifacts(from: result.tokenTimings ?? [], audioDurationSec: durationSec)
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
        durationSec: durationSec,
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

func measureAudioDurationSec(at url: URL) -> Double? {
    guard let audioFile = try? AVAudioFile(forReading: url) else {
        return nil
    }
    let sampleRate = audioFile.fileFormat.sampleRate
    guard sampleRate > 0 else {
        return nil
    }
    let duration = Double(audioFile.length) / sampleRate
    return duration.isFinite && duration > 0 ? duration : nil
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
            audioDurationSec: measureAudioDurationSec(at: inputURL),
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
