import AVFoundation
import Foundation

enum AudioConverter {
    /// Input audio format for sending to Gemini: 16kHz PCM16 mono little-endian
    static var inputFormat: AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Constants.inputSampleRate, channels: 1, interleaved: true)!
    }

    /// Output audio format for receiving from Gemini: 24kHz PCM16 mono little-endian
    static var outputFormat: AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Constants.outputSampleRate, channels: 1, interleaved: true)!
    }

    /// Convert an AVAudioPCMBuffer from hardware format to 16kHz PCM16 mono (for sending to API)
    static func convertToAPIFormat(buffer: AVAudioPCMBuffer, using converter: AVAudioConverter) -> AVAudioPCMBuffer? {
        let ratio = Constants.inputSampleRate / buffer.format.sampleRate
        let outputFrameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: outputFrameCount) else {
            return nil
        }

        var error: NSError?
        var hasData = true

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                hasData = false
                outStatus.pointee = .haveData
                return buffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        if let error = error {
            print("[AudioConverter] Conversion to API format failed: \(error.localizedDescription)")
            return nil
        }

        return outputBuffer
    }

    /// Convert 24kHz PCM16 mono data (received from API) to an AVAudioPCMBuffer in the hardware output format
    static func convertFromAPIFormat(data: Data, to hardwareFormat: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frameCount = UInt32(data.count) / 2 // PCM16 = 2 bytes per frame per channel

        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: frameCount) else {
            return nil
        }

        inputBuffer.frameLength = frameCount

        guard let int16Data = inputBuffer.int16ChannelData else {
            return nil
        }

        data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            int16Data[0].update(from: baseAddress.assumingMemoryBound(to: Int16.self), count: Int(frameCount))
        }

        // If hardware format matches API output format, return directly
        if hardwareFormat.sampleRate == Constants.outputSampleRate &&
           hardwareFormat.channelCount == 1 &&
           hardwareFormat.commonFormat == .pcmFormatInt16 {
            return inputBuffer
        }

        guard let converter = AVAudioConverter(from: outputFormat, to: hardwareFormat) else {
            return nil
        }

        let ratio = hardwareFormat.sampleRate / Constants.outputSampleRate
        let outputFrameCount = AVAudioFrameCount(Double(frameCount) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: hardwareFormat, frameCapacity: outputFrameCount) else {
            return nil
        }

        var error: NSError?
        var hasData = true

        converter.convert(to: outputBuffer, error: &error) { _, outStatus in
            if hasData {
                hasData = false
                outStatus.pointee = .haveData
                return inputBuffer
            } else {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        if let error = error {
            print("[AudioConverter] Conversion from API format failed: \(error.localizedDescription)")
            return nil
        }

        return outputBuffer
    }

    /// Extract raw PCM16 bytes from an AVAudioPCMBuffer
    static func bufferToData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let int16Data = buffer.int16ChannelData else { return nil }
        let byteCount = Int(buffer.frameLength) * MemoryLayout<Int16>.size
        return Data(bytes: int16Data[0], count: byteCount)
    }

    /// Compute RMS audio level from a PCM buffer (returns 0.0 to 1.0)
    static func rmsLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard buffer.frameLength > 0 else { return 0.0 }

        if let floatData = buffer.floatChannelData {
            var sum: Float = 0
            let channelData = floatData[0]
            for i in 0..<Int(buffer.frameLength) {
                let sample = channelData[i]
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(buffer.frameLength))
            return min(rms * 2.0, 1.0) // Scale up slightly for visibility
        }

        if let int16Data = buffer.int16ChannelData {
            var sum: Float = 0
            let channelData = int16Data[0]
            for i in 0..<Int(buffer.frameLength) {
                let sample = Float(channelData[i]) / Float(Int16.max)
                sum += sample * sample
            }
            let rms = sqrt(sum / Float(buffer.frameLength))
            return min(rms * 2.0, 1.0)
        }

        return 0.0
    }
}
