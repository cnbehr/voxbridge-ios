import SwiftUI

struct TranscriptView: View {
    let entries: [SessionState.TranscriptEntry]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if entries.isEmpty {
                        VStack(spacing: 8) {
                            Text("Translations will appear here")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    }

                    ForEach(entries) { entry in
                        TranscriptBubble(entry: entry)
                            .id(entry.id)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onChange(of: entries.count) { _, _ in
                if let lastEntry = entries.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastEntry.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

struct TranscriptBubble: View {
    let entry: SessionState.TranscriptEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.text)
                .font(.body)
                .foregroundStyle(entry.isPartial ? .secondary : .primary)

            Text(entry.timeString)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
                .opacity(entry.isPartial ? 0.5 : 1.0)
        )
    }
}

#Preview {
    TranscriptView(entries: [
        SessionState.TranscriptEntry(text: "Hello, how are you?", timestamp: Date(), isPartial: false),
        SessionState.TranscriptEntry(text: "I'm doing well, thanks for asking.", timestamp: Date(), isPartial: false),
        SessionState.TranscriptEntry(text: "Would you like to...", timestamp: Date(), isPartial: true),
    ])
    .preferredColorScheme(.dark)
}
