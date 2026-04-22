@preconcurrency import AVFoundation
import FluidAudio
import Foundation

struct PreparedInput {
    let originalURL: URL
    let processingURL: URL
    let normalizationStrategy: String?
    let cleanupDirectoryURL: URL?

    var wasNormalized: Bool {
        cleanupDirectoryURL != nil
    }

    func cleanup() {
        guard let cleanupDirectoryURL else { return }
        try? FileManager.default.removeItem(at: cleanupDirectoryURL)
    }
}

enum InputPreparation {
    private static let targetSampleRate = 16_000.0

    static func prepareForSynchronousCLI(url: URL) throws -> PreparedInput {
        let semaphore = DispatchSemaphore(value: 0)
        let resultBox = PreparedInputResultBox()

        Task.detached(priority: .userInitiated) {
            do {
                resultBox.outcome = .success(try await prepareAsync(url: url))
            } catch {
                resultBox.outcome = .failure(error)
            }
            semaphore.signal()
        }

        semaphore.wait()
        switch resultBox.outcome {
        case let .success(preparedInput):
            return preparedInput
        case let .failure(error):
            throw error
        case .none:
            throw AppError.inputPreparationFailed("Unexpected missing input preparation result")
        }
    }

    private static func prepareAsync(url: URL) async throws -> PreparedInput {
        let extensionLowercased = url.pathExtension.lowercased()
        if extensionLowercased == "wav" {
            return PreparedInput(
                originalURL: url,
                processingURL: url,
                normalizationStrategy: nil,
                cleanupDirectoryURL: nil
            )
        }

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("fluid-transcription", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let normalizedURL = tempDirectory.appendingPathComponent("normalized-input.wav")
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        do {
            try await normalizeWithAVFoundation(inputURL: url, outputURL: normalizedURL)
            return PreparedInput(
                originalURL: url,
                processingURL: normalizedURL,
                normalizationStrategy: "avfoundation",
                cleanupDirectoryURL: tempDirectory
            )
        } catch {
            do {
                try normalizeWithFFmpeg(inputURL: url, outputURL: normalizedURL)
                return PreparedInput(
                    originalURL: url,
                    processingURL: normalizedURL,
                    normalizationStrategy: "ffmpeg",
                    cleanupDirectoryURL: tempDirectory
                )
            } catch {
                try? FileManager.default.removeItem(at: tempDirectory)
                throw AppError.inputPreparationFailed(
                    "Failed to prepare input media for processing. Native decode did not succeed and no compatible fallback completed for: \(url.path)"
                )
            }
        }
    }

    private static func normalizeWithAVFoundation(inputURL: URL, outputURL: URL) async throws {
        let asset = AVURLAsset(url: inputURL)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AppError.inputPreparationFailed("No audio track found in input media: \(inputURL.path)")
        }

        let reader = try AVAssetReader(asset: asset)
        let readerOutput = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ]
        )
        readerOutput.alwaysCopiesSampleData = false

        guard reader.canAdd(readerOutput) else {
            throw AppError.inputPreparationFailed("Unable to create a native audio decode pipeline for input media: \(inputURL.path)")
        }

        reader.add(readerOutput)
        guard reader.startReading() else {
            throw reader.error ?? AppError.inputPreparationFailed("AVAssetReader failed to start for input media: \(inputURL.path)")
        }

        let converter = AudioConverter(sampleRate: targetSampleRate)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AppError.inputPreparationFailed("Failed to create normalized output audio format")
        }
        let outputFile = try AVAudioFile(forWriting: outputURL, settings: outputFormat.settings)
        var totalFramesWritten: AVAudioFrameCount = 0

        while reader.status == .reading {
            guard let sampleBuffer = readerOutput.copyNextSampleBuffer() else {
                break
            }

            let samples = try converter.resampleSampleBuffer(sampleBuffer)
            if samples.isEmpty {
                continue
            }

            try append(samples: samples, to: outputFile, using: outputFormat)
            totalFramesWritten += AVAudioFrameCount(samples.count)
        }

        if reader.status == .failed {
            throw reader.error ?? AppError.inputPreparationFailed("Native input decoding failed for: \(inputURL.path)")
        }

        if totalFramesWritten == 0 {
            throw AppError.inputPreparationFailed("Decoded audio contained no writable samples: \(inputURL.path)")
        }
    }

    private static func append(samples: [Float], to outputFile: AVAudioFile, using format: AVAudioFormat) throws {
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw AppError.inputPreparationFailed("Failed to create a write buffer for normalized audio")
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        guard let channelData = buffer.floatChannelData else {
            throw AppError.inputPreparationFailed("Failed to access normalized audio channel data")
        }

        _ = samples.withUnsafeBufferPointer { source in
            memcpy(channelData[0], source.baseAddress!, samples.count * MemoryLayout<Float>.stride)
        }

        try outputFile.write(from: buffer)
    }

    private static func normalizeWithFFmpeg(inputURL: URL, outputURL: URL) throws {
        let ffmpegURL = try findFFmpeg()
        let process = Process()
        process.executableURL = ffmpegURL
        process.arguments = [
            "-y",
            "-i", inputURL.path,
            "-ac", "1",
            "-ar", "16000",
            "-c:a", "pcm_s16le",
            outputURL.path,
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw AppError.inputPreparationFailed(
                "FFmpeg input normalization failed\(message.map { ": \($0)" } ?? "")"
            )
        }

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw AppError.inputPreparationFailed("FFmpeg reported success but did not create normalized audio output")
        }
    }

    private static func findFFmpeg() throws -> URL {
        let commonPaths = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg",
        ]

        for path in commonPaths where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw AppError.inputPreparationFailed("No supported fallback decoder was available. Install ffmpeg or provide a natively decodable input format.")
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let output, !output.isEmpty, FileManager.default.isExecutableFile(atPath: output) else {
            throw AppError.inputPreparationFailed("No supported fallback decoder was available. Install ffmpeg or provide a natively decodable input format.")
        }

        return URL(fileURLWithPath: output)
    }
}

final class PreparedInputResultBox: @unchecked Sendable {
    var outcome: Result<PreparedInput, Error>?
}