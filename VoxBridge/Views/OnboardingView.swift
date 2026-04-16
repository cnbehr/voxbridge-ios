import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var viewModel: InterpreterViewModel
    @State private var apiKeyInput: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // App icon / title
            VStack(spacing: 12) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                Text("VoxBridge")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Real-time interpreter earpiece")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // API Key input
            VStack(alignment: .leading, spacing: 12) {
                Text("Google AI API Key")
                    .font(.headline)

                Text("VoxBridge uses the Gemini Live API for real-time translation. You'll need a Google AI API key from Google AI Studio.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                SecureField("AIza...", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(.body, design: .monospaced))

                if showError {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Link("Get an API key from Google AI Studio",
                     destination: URL(string: "https://aistudio.google.com/apikey")!)
                    .font(.caption)
            }
            .padding(.horizontal, 24)

            // Submit button
            Button(action: saveKey) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
            .padding(.horizontal, 24)

            Spacer()

            Text("Your API key is stored securely in the iOS Keychain and never leaves your device except to authenticate with Google AI.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }

    private func saveKey() {
        let key = apiKeyInput.trimmingCharacters(in: .whitespaces)

        guard key.hasPrefix("AIza") else {
            errorMessage = "API key should start with 'AIza'"
            showError = true
            return
        }

        guard key.count > 20 else {
            errorMessage = "API key seems too short"
            showError = true
            return
        }

        showError = false
        viewModel.saveAPIKey(key)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(InterpreterViewModel())
        .preferredColorScheme(.dark)
}
