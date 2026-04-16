import SwiftUI

struct ListeningView: View {
    @EnvironmentObject var viewModel: InterpreterViewModel
    @ObservedObject private var sessionState: SessionState

    init() {
        // This will be replaced by the actual sessionState from viewModel via onAppear
        self._sessionState = ObservedObject(wrappedValue: SessionState())
    }

    var body: some View {
        VStack(spacing: 0) {
            // Status bar
            statusBar
                .padding(.horizontal, 20)
                .padding(.top, 16)

            // Waveform
            WaveformView(
                inputLevel: viewModel.sessionState.inputAudioLevel,
                outputLevel: viewModel.sessionState.outputAudioLevel,
                isTranslating: viewModel.sessionState.isTranslating
            )
            .frame(height: 120)
            .padding(.horizontal, 20)
            .padding(.top, 24)

            // Connection status
            connectionStatusView
                .padding(.top, 12)

            // Warning
            if let warning = viewModel.sessionState.sessionWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.top, 8)
            }

            // Transcript
            TranscriptView(entries: viewModel.sessionState.transcriptEntries)
                .padding(.top, 16)

            Spacer()

            // Bottom controls
            bottomControls
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack {
            // Timer
            VStack(alignment: .leading, spacing: 2) {
                Text("Session")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(formatTime(viewModel.sessionState.elapsedTime))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
            }

            Spacer()

            // Languages
            VStack(spacing: 2) {
                Text("\(viewModel.foreignLanguage.displayName) → \(viewModel.userLanguage.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Cost
            VStack(alignment: .trailing, spacing: 2) {
                Text("Cost")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "$%.2f", viewModel.sessionState.estimatedCost))
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.medium)
            }
        }
    }

    // MARK: - Connection Status

    private var connectionStatusView: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(viewModel.sessionState.connectionStatus.displayText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch viewModel.sessionState.connectionStatus {
        case .connected: return .green
        case .connecting, .reconnecting: return .orange
        case .error: return .red
        case .disconnected: return .gray
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        Button(action: {
            viewModel.stopListening()
        }) {
            HStack(spacing: 10) {
                Image(systemName: "stop.circle.fill")
                    .font(.title2)
                Text("Stop")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
    }

    // MARK: - Helpers

    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ListeningView()
        .environmentObject(InterpreterViewModel())
        .preferredColorScheme(.dark)
}
