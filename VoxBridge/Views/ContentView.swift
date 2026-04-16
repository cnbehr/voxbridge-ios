import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: InterpreterViewModel

    var body: some View {
        Group {
            if viewModel.showOnboarding {
                OnboardingView()
            } else if viewModel.sessionState.isListening {
                ListeningView()
            } else {
                SetupView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.showOnboarding)
        .animation(.easeInOut(duration: 0.3), value: viewModel.sessionState.isListening)
    }
}

#Preview {
    ContentView()
        .environmentObject(InterpreterViewModel())
}
