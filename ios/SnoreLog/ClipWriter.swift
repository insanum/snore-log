import AVFoundation

/// Writes a clip to disk as compressed AAC audio (.m4a, about 0.25 MB a minute),
/// falling back to uncompressed WAV if the encoder isn't available.
enum ClipWriter {
    struct Written {
        var fileName: String
        var bytes: Int64
    }

    static func write(_ samples: [Float], sampleRate: Double, start: Date, to dir: URL) throws -> Written {
        let stamp = fileStamp(start)
        do {
            let name = "snore-\(stamp).m4a"
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32000,
            ]
            try writeFile(samples, sampleRate: sampleRate, settings: settings, url: dir.appendingPathComponent(name))
            return Written(fileName: name, bytes: size(dir.appendingPathComponent(name)))
        } catch {
            let name = "snore-\(stamp).wav"
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
            ]
            try writeFile(samples, sampleRate: sampleRate, settings: settings, url: dir.appendingPathComponent(name))
            return Written(fileName: name, bytes: size(dir.appendingPathComponent(name)))
        }
    }

    private static func writeFile(_ samples: [Float], sampleRate: Double, settings: [String: Any], url: URL) throws {
        try? FileManager.default.removeItem(at: url)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate,
                                         channels: 1, interleaved: false) else {
            throw CocoaError(.fileWriteUnknown)
        }
        // The file is closed when `file` goes out of scope at the end of this function.
        let file = try AVAudioFile(forWriting: url, settings: settings,
                                   commonFormat: .pcmFormatFloat32, interleaved: false)
        let block = 16384
        var offset = 0
        while offset < samples.count {
            let n = min(block, samples.count - offset)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(n)),
                  let channel = buffer.floatChannelData?[0] else {
                throw CocoaError(.fileWriteUnknown)
            }
            buffer.frameLength = AVAudioFrameCount(n)
            samples.withUnsafeBufferPointer { src in
                guard let base = src.baseAddress else { return }
                channel.update(from: base + offset, count: n)
            }
            try file.write(from: buffer)
            offset += n
        }
    }

    private static func size(_ url: URL) -> Int64 {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attrs?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func fileStamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'_'HH-mm-ss"
        return f.string(from: date)
    }
}
