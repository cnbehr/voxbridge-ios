import AVFoundation
import Foundation
import Combine

final class AudioSessionManager: ObservableObject {
    @Published var isHeadphonesConnected: Bool = false

    private var routeChangeObserver: NSObjectProtocol?

    var onHeadphonesDisconnected: (() -> Void)?

    init() {
        checkHeadphones()
        observeRouteChanges()
    }

    deinit {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func configureSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.allowBluetooth, .allowBluetoothA2DP]
        )
        try session.setActive(true)
        checkHeadphones()
    }

    func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("[AudioSessionManager] Failed to deactivate session: \(error.localizedDescription)")
        }
    }

    private func checkHeadphones() {
        let route = AVAudioSession.sharedInstance().currentRoute
        isHeadphonesConnected = route.outputs.contains { output in
            [.headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE].contains(output.portType)
        }
    }

    private func observeRouteChanges() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }

            guard let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                return
            }

            self.checkHeadphones()

            if reason == .oldDeviceUnavailable {
                // Headphones disconnected - pause to avoid speaker blast
                self.onHeadphonesDisconnected?()
            }
        }
    }
}
