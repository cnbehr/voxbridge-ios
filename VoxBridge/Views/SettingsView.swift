import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var viewModel: InterpreterViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var newAPIKey: String = ""
    @State private var showAPIKeyField = false

    var body: some View {
        NavigationStack {
            List {
                // API Key section
                Section {
                    HStack {
                        Text("API Key")
                        Spacer()
                        if viewModel.hasAPIKey {
                            Text("Configured")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text("Not set")
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                    }

                    if showAPIKeyField {
                        SecureField("sk-...", text: $newAPIKey)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.system(.body, design: .monospaced))

                        Button("Save Key") {
                            if !newAPIKey.isEmpty {
                                viewModel.saveAPIKey(newAPIKey)
                                newAPIKey = ""
                                showAPIKeyField = false
                            }
                        }
                        .disabled(newAPIKey.isEmpty)
                    } else {
                        Button("Update API Key") {
                            showAPIKeyField = true
                        }
                    }

                    Button("Remove API Key", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .disabled(!viewModel.hasAPIKey)
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    Text("Your key is stored in the iOS Keychain and never sent anywhere except OpenAI.")
                }

                // Voice section
                Section {
                    Picker("Translation Voice", selection: $viewModel.selectedVoice) {
                        ForEach(Voice.allCases) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                } header: {
                    Text("Voice")
                } footer: {
                    Text("The voice used for spoken translations. Cannot be changed during an active session.")
                }

                // Cost info section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        CostRow(label: "Audio input", cost: "$0.06/min")
                        CostRow(label: "Audio output", cost: "$0.24/min")
                        Divider()
                        CostRow(label: "Combined", cost: "~$0.30/min")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Estimated Costs")
                } footer: {
                    Text("Based on GPT-4o Realtime pricing. Actual costs depend on speech density.")
                }

                // About section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Model")
                        Spacer()
                        Text("gpt-4o-realtime-preview")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }

                    HStack {
                        Text("Session Limit")
                        Spacer()
                        Text("60 minutes")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        viewModel.savePreferences()
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Remove API Key?", isPresented: $showDeleteConfirmation) {
                Button("Remove", role: .destructive) {
                    viewModel.deleteAPIKey()
                    viewModel.showOnboarding = true
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove your OpenAI API key. You'll need to enter it again to use VoxBridge.")
            }
        }
    }
}

struct CostRow: View {
    let label: String
    let cost: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(cost)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(InterpreterViewModel())
        .preferredColorScheme(.dark)
}
