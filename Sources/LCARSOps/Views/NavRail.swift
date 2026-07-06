import SwiftUI

struct NavRail: View {
    @ObservedObject var model: FileSystemModel
    private let cycle: [Color] = [LC.salmon, LC.orange, LC.amber, LC.plum, LC.salmon]

    var body: some View {
        VStack(spacing: Metric.outerGap) {
            ForEach(Array(model.railItems.enumerated()), id: \.offset) { i, item in
                RailButton(label: item.label,
                           color: model.railActive(item.url) ? LC.cream
                                    : (i == 0 ? LC.amber : cycle[(i - 1) % cycle.count])) {
                    model.navigate(to: item.url)
                }
            }

            // decorative filler with reference codes
            ZStack(alignment: .topTrailing) {
                LC.brownFill
                VStack(alignment: .trailing, spacing: 8) {
                    ForEach(LC.railCodes, id: \.self) { code in
                        Text(code).lcars(12, .semibold, tracking: 1.5, color: LC.black.opacity(0.6))
                    }
                }
                .padding(.trailing, 12)
                .padding(.top, 10)
            }
            .frame(maxHeight: .infinity)

            storagePanel
        }
        .frame(width: Metric.railWidth)
    }

    private var storagePanel: some View {
        let pct = Int((model.usedFraction * 100).rounded())
        return VStack(alignment: .leading, spacing: 0) {
            Text("STORAGE").lcars(13, .bold, tracking: 1.5, color: LC.black)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(LC.black)
                    Capsule().fill(LC.cream)
                        .frame(width: max(0, geo.size.width * model.usedFraction))
                }
            }
            .frame(height: 12)
            .padding(.top, 10)
            Text("\(pct)% ALLOCATED")
                .lcars(13, .semibold, tracking: 0.5, color: LC.black.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(height: 88)
        .background(LC.salmon)
    }
}

private struct RailButton: View {
    let label: String
    let color: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                color
                Text(label).lcars(14, .bold, tracking: 1, color: LC.black)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .padding(.trailing, 12)
                    .padding(.bottom, 7)
            }
            .frame(height: 54)
            .frame(maxWidth: .infinity)
            .brightness(hovering ? 0.08 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
