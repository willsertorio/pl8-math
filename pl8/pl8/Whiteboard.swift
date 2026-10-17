import SwiftUI
import PlateKit

/// Today's strength work, written out like the box's whiteboard.
struct Whiteboard: View {
    let blocks: [StrengthBlock]
    var title = "Whiteboard"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Theme.heading)
            if blocks.isEmpty {
                Text("No strength work.").foregroundStyle(Theme.ink)
            }
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline(block)).font(.headline)
                    if let rpe = block.rpe, block.pctMissing {
                        Text("\(sets(block)) · RPE \(WeightUnit.trimmed(rpe))/10 · suggested \(block.suggestedTarget?.text ?? "")")
                            .font(.subheadline)
                            .foregroundStyle(.orange)
                    } else if block.pctMissing {
                        Text("\(sets(block)) · % missing").font(.subheadline).foregroundStyle(.orange)
                    } else {
                        Text("\(sets(block)) · \(percents(block))")
                            .font(.subheadline)
                            .foregroundStyle(Theme.ink)
                    }
                    if let note = block.note {
                        Text(note).font(.footnote).foregroundStyle(Theme.ink)
                    }
                }
            }
        }
        .drawer()
    }

    /// "A · After Party · Back Squat · EMOM"
    private func headline(_ block: StrengthBlock) -> String {
        let parts: [String?] = [block.letter, block.label, block.name, block.format]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    /// "5 × 3"
    private func sets(_ block: StrengthBlock) -> String {
        "\(block.sets.count) × \(block.sets.first?.reps ?? 0)"
    }

    /// "75–78%, 75–78%, 78–80%…", or one value when every set is the same.
    private func percents(_ block: StrengthBlock) -> String {
        let texts = block.sets.compactMap { $0.target?.text }
        if let first = texts.first, texts.allSatisfy({ $0 == first }) { return first }
        return texts.joined(separator: ", ")
    }
}

/// The spinning plate shown while a workout is being read.
struct PlateSpinner: View {
    @State private var angle = 0.0

    var body: some View {
        ZStack {
            Circle().fill(Color(hex: "#1E5BC6"))
            Circle().stroke(Theme.ink, lineWidth: 2)
            Circle().fill(Theme.paper).frame(width: 14, height: 14)
            Rectangle().fill(Theme.paper.opacity(0.7)).frame(width: 4, height: 14).offset(y: -18)
        }
        .frame(width: 56, height: 56)
        .rotationEffect(.degrees(angle))
        .onAppear {
            withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) { angle = 360 }
        }
    }
}
