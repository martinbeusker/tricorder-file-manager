import SwiftUI

// MARK: - Top-left sweeping elbow (amber block with a carved black notch)
struct TopLeftElbow: View {
    var body: some View {
        ZStack {
            UnevenRoundedRectangle(topLeadingRadius: 46).fill(LC.amber)
            // black notch carved from the bottom-right → forms the elbow that
            // flows into the header bar
            UnevenRoundedRectangle(topLeadingRadius: 30)
                .fill(LC.black)
                .frame(width: 64, height: 40)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)

            Text("FILE OPS").lcars(21, .bold, tracking: 1.5, color: LC.black)
                .padding(.leading, 20).padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            Text("05-2141").lcars(13, .semibold, tracking: 1, color: LC.black.opacity(0.55))
                .padding(.trailing, 74).padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: Metric.elbowWidth, height: Metric.topFrameHeight)
    }
}

// MARK: - Bottom-left elbow
struct BottomLeftElbow: View {
    var body: some View {
        ZStack {
            UnevenRoundedRectangle(bottomLeadingRadius: 46).fill(LC.orange)
            UnevenRoundedRectangle(bottomLeadingRadius: 24)
                .fill(LC.black)
                .frame(width: 64, height: 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            Text("FMX-02").lcars(16, .bold, tracking: 1.5, color: LC.black)
                .padding(.leading, 20).padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: Metric.elbowWidth, height: Metric.bottomFrameHeight)
    }
}

// MARK: - Rounded pill end cap (right side)
struct EndCap: View {
    var color: Color
    var radius: CGFloat = 26
    var width: CGFloat = Metric.capWidth
    var body: some View {
        UnevenRoundedRectangle(bottomTrailingRadius: radius, topTrailingRadius: radius)
            .fill(color)
            .frame(width: width)
    }
}

// MARK: - Blinking status dot
struct BlinkDot: View {
    let delay: Double
    let motion: Bool
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(LC.black)
            .frame(width: 10, height: 10)
            .opacity(motion ? (dim ? 0.12 : 1) : 1)
            .onAppear { start() }
            .onChange(of: motion) { _, on in
                if on { start() } else { dim = false }
            }
    }

    private func start() {
        guard motion else { return }
        dim = false
        withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true).delay(delay)) {
            dim = true
        }
    }
}

// MARK: - Generic pill button used for crumbs / column headers / actions
struct LCARSButton: View {
    let title: String
    var bg: Color
    var fg: Color = LC.black
    var size: CGFloat = 14
    var weight: AntonioWeight = .bold
    var tracking: CGFloat = 1.5
    var radius: CGFloat = 15
    var padH: CGFloat = 14
    var padV: CGFloat = 6
    var align: Alignment = .center
    var hoverBrighten = true
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title).lcars(size, weight, tracking: tracking, color: fg)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: align)
                .padding(.horizontal, padH)
                .padding(.vertical, padV)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .brightness(hovering && hoverBrighten ? 0.06 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
