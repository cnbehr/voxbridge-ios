import AVFoundation
import Foundation

final class AudioCaptureService {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let sendQueue = DispatchQueue(label: "voxbridge.audio.send", qos: .userInitiated)

    var onAudioCaptured: ((Data) -> Void)?
    var onAudioLevel: ((Float) -> Void)?

    private(set) var isCapturing = false

    func startCapture() throws {
        guard !isCapturing else { return }

        let inputNode = engine.inputNode
        let hardwareFormat = inputNode.outputFormat(forBus: 0)

        guard hardwareFormat.sampleRate > 0 else {
            throw AudioCaptureError.invalidFormat
        }

        let apiFormat = AudioConverter.apiFormat

        guard let audioConverter = AVAudioConverter(from: hardwareFormat, to: apiFormat) else {
            throw AudioCaptureError.converterCreationFailed
        }
        self.converter = audioConverter

        inputNode.installTap(
            onBus: 0,
            bufferSize: Constants.captureBufferSize,
            format: hardwareFormat
        ) { [weak self] buffer, _ in
            guard let self = self else { return }

            // Compute audio level on the raw buffer
            let level = AudioConverter.rmsLevel(of: buffer)
            self.onAudioLevel?(level)

            self.sendQueue.async { [weak self] in
                guard let self = self,
                      let converter = self.converter else { return }

                guard let convertedBuffer = AudioConverter.convertToAPIFormat(buffer: buffer, using: converter) else {
                    return
                }

                guard let data = AudioConverter.bufferToData(convertedBuffer) else {
                    return
                }

                self.onAudioCaptured?(data)
            }
        }

        try engine.start()
        isCapturing = true
    }

    func stopCapture() {
        guard isCapturing else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        isCapturing = false
    }

    enum AudioCaptureError: LocalizedError {
        case invalidFormat
        case converterCreationFailed

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "Invalid audio input format"
            case .converterCreationFailed:
                return "Failed to create audio format converter"
            }
        }
    }
}
