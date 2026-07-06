import SwiftUI

struct BottomFrame: View {
    @ObservedObject var model: FileSystemModel

    private var freeLabel: String {
        let free = Fmt.bytes(model.diskFree)
        return "\(free) FREE · NODE 7 · LINK STABLE"
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: Metric.outerGap) {
            BottomLeftElbow()

            HStack(spacing: Metric.outerGap) {
                Text(model.isFiltering
                     ? "\(model.visibleItems.count)\(model.searchTruncated ? "+" : "") MATCHES"
                     : "\(model.items.count) OBJECTS")
                    .lcars(14, .bold, tracking: 1.2, color: LC.black)
                    .frame(width: 200, alignment: .trailing)
                    .frame(maxHeight: .infinity)
                    .padding(.trailing, 14)
                    .background(LC.amber)

                Text(freeLabel)
                    .lcars(12, .semibold, tracking: 2, color: LC.black.opacity(0.6))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .frame(maxHeight: .infinity)
                    .background(LC.brownFill)

                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(clock(ctx.date))
                        .lcars(15, .bold, tracking: 2, color: LC.black)
                        .frame(width: 120)
                        .frame(maxHeight: .infinity)
                        .background(LC.cream)
                }

                EndCap(color: LC.salmon, radius: 18)
            }
            .frame(height: Metric.bottomBarHeight)
        }
        .frame(height: Metric.bottomFrameHeight)
    }

    private func clock(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        return String(format: "%02d:%02d:%02d", c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
    }
}
