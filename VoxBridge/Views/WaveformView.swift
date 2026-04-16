import SwiftUI

struct WaveformView: View {
    let inputLevel: Float
    let outputLevel: Float
    let isTranslating: Bool

    @State private var animationPhase: CGFloat = 0

    private let barCount = 40
    private let minBarHeight: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    let normalizedIndex = CGFloat(index) / CGFloat(barCount)
                    let waveOffset = sin(normalizedIndex * .pi * 3 + animationPhase)
                    let level = isTranslating ? CGFloat(outputLevel) : CGFloat(inputLevel)
                    let barHeight = max(minBarHeight, level * geometry.size.height * CGFloat(0.5 + 0.5 * waveOffset))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(for: index))
                        .frame(width: max((geometry.size.width / CGFloat(barCount)) - 2, 2),
                               height: barHeight)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                animationPhase = .pi * 2
            }
        }
    }

    private func barColor(for index: Int) -> Color {
        if isTranslating {
            return .blue.opacity(0.6 + 0.4 * Double(outputLevel))
        } else if inputLevel > 0.01 {
            return .green.opacity(0.4 + 0.6 * Double(inputLevel))
        } else {
            return .gray.opacity(0.3)
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        WaveformView(inputLevel: 0.3, outputLevel: 0.0, isTranslating: false)
            .frame(height: 120)

        WaveformView(inputLevel: 0.0, outputLevel: 0.6, isTranslating: true)
            .frame(height: 120)
    }
    .padding()
    .background(Color.black)
    .preferredColorScheme(.dark)
}
