import SwiftUI

struct SetupView: View {
    @EnvironmentObject var viewModel: InterpreterViewModel
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                // Language selection
                VStack(spacing: 20) {
                    // User language
                    VStack(alignment: .leading, spacing: 6) {
                        Text("I speak")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("I speak", selection: $viewModel.userLanguage) {
                            ForEach(Language.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Swap button
                    Button {
                        let temp = viewModel.userLanguage
                        viewModel.userLanguage = viewModel.foreignLanguage
                        viewModel.foreignLanguage = temp
                    } label: {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    .disabled(viewModel.userLanguage == viewModel.foreignLanguage)

                    // Foreign language
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Translate from")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Picker("Translate from", selection: $viewModel.foreignLanguage) {
                            ForEach(Language.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal, 24)

                // Voice selector
                VStack(alignment: .leading, spacing: 6) {
                    Text("Translation voice")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Picker("Voice", selection: $viewModel.selectedVoice) {
                        ForEach(Voice.allCases) { voice in
                            Text(voice.displayName).tag(voice)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 24)

                Spacer()

                // Cost note
                Text("Estimated cost: ~$0.30/min while active")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Same language warning
                if viewModel.userLanguage == viewModel.foreignLanguage {
                    Text("Source and target languages must be different")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                // Start button
                Button(action: startSession) {
                    HStack(spacing: 10) {
                        Image(systemName: "ear.and.waveform")
                        Text("Start Listening")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .disabled(viewModel.userLanguage == viewModel.foreignLanguage)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .navigationTitle("VoxBridge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private func startSession() {
        viewModel.savePreferences()
        viewModel.startListening()
    }
}

#Preview {
    SetupView()
        .environmentObject(InterpreterViewModel())
        .preferredColorScheme(.dark)
}
