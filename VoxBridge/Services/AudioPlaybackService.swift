import AVFoundation
import Foundation
import UIKit

final class AudioPlaybackService {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var outputConverter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?

    var onOutputLevel: ((Float) -> Void)?

    private(set) var isPlaying = false

    func setup() throws {
        engine.attach(playerNode)

        let mainMixer = engine.mainMixerNode
        outputFormat = mainMixer.outputFormat(forBus: 0)

        engine.connect(playerNode, to: mainMixer, format: outputFormat)

        try engine.start()
        playerNode.play()
        isPlaying = true
    }

    func scheduleAudio(data: Data) {
        guard isPlaying, let outputFormat = outputFormat else { return }

        guard let buffer = AudioConverter.convertFromAPIFormat(data: data, to: outputFormat) else {
            print("[AudioPlayback] Failed to convert audio data")
            return
        }

        // Compute output level
        let level = AudioConverter.rmsLevel(of: buffer)
        onOutputLevel?(level)

        // Haptic feedback when translation starts
        triggerHaptic()

        playerNode.scheduleBuffer(buffer)
    }

    func stop() {
        guard isPlaying else { return }
        playerNode.stop()
        engine.stop()
        engine.detach(playerNode)
        outputConverter = nil
        outputFormat = nil
        isPlaying = false
    }

    private var lastHapticTime: Date = .distantPast

    private func triggerHaptic() {
        let now = Date()
        // Throttle haptics to at most once per 2 seconds
        guard now.timeIntervalSince(lastHapticTime) > 2.0 else { return }
        lastHapticTime = now

        DispatchQueue.main.async {
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        }
    }
}
