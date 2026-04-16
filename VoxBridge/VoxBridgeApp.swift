import SwiftUI

@main
struct VoxBridgeApp: App {
    @StateObject private var viewModel = InterpreterViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .preferredColorScheme(.dark)
        }
    }
}
