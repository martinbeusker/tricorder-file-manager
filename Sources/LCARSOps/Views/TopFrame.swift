import SwiftUI

struct TopFrame: View {
    @ObservedObject var model: FileSystemModel

    private var statusText: String {
        if let s = model.status { return s }
        if model.searching { return "SCANNING\u{2026} \(model.visibleItems.count) FOUND" }
        return model.redAlert ? "RED ALERT · ACCESS RESTRICTED" : "ALL SYSTEMS NOMINAL"
    }
    private var statusBg: Color {
        if model.status != nil || model.searching { return LC.amber }
        return model.redAlert ? LC.red : LC.cream
    }

    var body: some View {
        HStack(alignment: .top, spacing: Metric.outerGap) {
            TopLeftElbow()

            HStack(spacing: Metric.outerGap) {
                breadcrumbBar
                statusBox
                EndCap(color: LC.plum)
            }
            .frame(height: Metric.headerBarHeight)
        }
        .frame(height: Metric.topFrameHeight)
    }

    // Breadcrumb chips on the cream bar
    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(model.crumbs.enumerated()), id: \.offset) { _, crumb in
                    LCARSButton(title: crumb.label,
                                bg: LC.black, fg: LC.cream,
                                size: 14, weight: .semibold, tracking: 1.2,
                                radius: 13, padH: 14, padV: 6,
                                hoverBrighten: false) {
                        model.navigate(to: crumb.url)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity)
        .background(LC.cream)
    }

    private var statusBox: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                BlinkDot(delay: 0,    motion: model.motion)
                BlinkDot(delay: 0.45, motion: model.motion)
                BlinkDot(delay: 0.9,  motion: model.motion)
            }
            Text(statusText).lcars(15, .bold, tracking: 1.5, color: LC.black)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .frame(width: Metric.statusWidth)
        .frame(maxHeight: .infinity)
        .background(statusBg)
    }
}
