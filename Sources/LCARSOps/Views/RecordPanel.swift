import SwiftUI

struct RecordPanel: View {
    @ObservedObject var model: FileSystemModel

    var body: some View {
        VStack(spacing: 12) {
            Text("FILE RECORD").lcars(14, .bold, tracking: 1.5, color: LC.black)
                .padding(.horizontal, 16).padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Capsule().fill(LC.salmon))

            if let sel = model.selected {
                detail(sel)
            } else {
                empty
            }
        }
    }

    private func pathString(for item: FileItem) -> String {
        model.pathLabels(for: item.url.deletingLastPathComponent()).joined(separator: " / ")
    }

    private func detail(_ sel: FileItem) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                Text(sel.name).lcars(25, .semibold, tracking: 1, color: LC.txt)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(1)

                PreviewFeed(item: sel, motion: model.motion)

                VStack(alignment: .leading, spacing: 8) {
                    metaRow("TYPE", sel.kind.recordName)
                    metaRow("SIZE", sel.isDir ? "\(sel.childCount ?? 0) OBJECTS" : Fmt.bytes(sel.size))
                    metaRow("MODIFIED", Fmt.date(sel.modified))
                    metaRow("PATH", pathString(for: sel))
                    metaRow("CHECKSUM", Fmt.checksum(sel.name))
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ActionButton(label: sel.isDir ? "OPEN" : "VIEW", bg: LC.amber) { model.open(sel) }
                    ActionButton(label: "COPY", bg: LC.cream) { model.copySelected() }
                    ActionButton(label: "MOVE", bg: LC.orange) { model.moveSelected() }
                    ActionButton(label: "PURGE", bg: LC.red) { model.purgeSelected() }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 2)
        }
    }

    private func metaRow(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(k).lcars(12, .bold, tracking: 1.5, color: LC.orange)
                .frame(width: 96, alignment: .leading)
            Text(v).lcars(15, .medium, tracking: 0.6, color: LC.txt)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Text("NO RECORD SELECTED").lcars(16, .semibold, tracking: 2, color: LC.brownButton)
            Text("SELECT AN OBJECT · DOUBLE-TAP TO OPEN")
                .lcars(13, .regular, tracking: 1, color: LC.panelDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundColor(LC.amber.opacity(0.3))
        )
    }
}

// MARK: - Preview feed: live text peek, image thumbnail, or animated placeholder
enum PreviewData {
    case loading
    case placeholder(String)              // label shown on the stripes
    case text([String], truncated: Bool)
    case image(NSImage)
}

private let previewHeight: CGFloat = 178

struct PreviewFeed: View {
    let item: FileItem
    let motion: Bool
    @State private var data: PreviewData = .loading

    var body: some View {
        content
            .frame(height: previewHeight)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(LC.amber.opacity(0.35), lineWidth: 1))
            .task(id: item.url) { data = await Self.load(item) }
    }

    @ViewBuilder private var content: some View {
        switch data {
        case .loading:
            PlaceholderFeed(label: "READING FEED…", motion: motion)
        case .placeholder(let label):
            PlaceholderFeed(label: label, motion: motion)
        case .image(let img):
            ZStack {
                Color.black
                Image(nsImage: img).resizable().interpolation(.high).scaledToFit().padding(5)
            }
        case .text(let lines, let truncated):
            TextFeed(lines: lines, truncated: truncated)
        }
    }

    // Load a bounded head of the file off the main thread.
    static func load(_ item: FileItem) async -> PreviewData {
        if item.isDir { return .placeholder("DIRECTORY · \(item.childCount ?? 0) OBJECTS") }
        if item.kind == .img {
            if item.size < 40_000_000, let img = NSImage(contentsOf: item.url) { return .image(img) }
            return .placeholder("IMAGE · \(Fmt.bytes(item.size))")
        }
        let head = await Task.detached { PreviewIO.readHead(item.url, max: 12_000) }.value
        guard let head else { return .placeholder("NO FEED · ACCESS DENIED") }
        if head.isEmpty { return .text(["[ EMPTY FILE ]"], truncated: false) }
        guard PreviewIO.looksLikeText(head) else {
            return .placeholder("BINARY · \(item.kind.label) · \(Fmt.bytes(item.size))")
        }
        var lines = String(decoding: head, as: UTF8.self)
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty, lines.count > 1 {
            lines.removeLast()
        }
        // Show only the head that fits the fixed-height feed box; flag the rest.
        let maxLines = 12
        let truncated = head.count >= 12_000 || lines.count > maxLines
        if lines.count > maxLines { lines = Array(lines.prefix(maxLines)) }
        return .text(lines, truncated: truncated)
    }
}

// LCARS terminal-style text readout
private struct TextFeed: View {
    let lines: [String]
    let truncated: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TEXT FEED").font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5).foregroundColor(LC.black)
                Spacer()
                Text("\(lines.count)\(truncated ? "+" : "") LN")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(LC.black)
            }
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(LC.orange)

            VStack(alignment: .leading, spacing: 1.5) {
                ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .top, spacing: 8) {
                        Text(String(format: "%03d", i + 1))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(LC.orange.opacity(0.7))
                        Text(line.isEmpty ? " " : line)
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(LC.txt)
                            .lineLimit(1).truncationMode(.tail)
                    }
                }
                if truncated {
                    Text("\u{22EF} FEED TRUNCATED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(LC.brownButton).padding(.top, 3)
                }
            }
            .padding(.horizontal, 8).padding(.top, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
        .background(Color(hex: 0x0D0A06))
    }
}

// Animated diagonal-stripe placeholder (original look, used for binary / images / dirs)
private struct PlaceholderFeed: View {
    let label: String
    let motion: Bool
    @State private var sweep = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                DiagonalStripes()
                LinearGradient(colors: [.clear, LC.amber.opacity(0.18), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: geo.size.height * 0.34)
                    .offset(y: sweep ? geo.size.height * 0.75 : -geo.size.height * 0.55)
                Text(label)
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(LC.brownButton)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
            }
            .onAppear { startSweep() }
            .onChange(of: motion) { _, _ in startSweep() }
        }
    }

    private func startSweep() {
        sweep = false
        guard motion else { return }
        withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) { sweep = true }
    }
}

// Pure IO helpers (no actor isolation)
enum PreviewIO {
    static func readHead(_ url: URL, max: Int) -> Data? {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? fh.close() }
        return (try? fh.read(upToCount: max)) ?? Data()
    }

    static func looksLikeText(_ d: Data) -> Bool {
        if d.isEmpty { return true }
        let sample = d.prefix(4096)
        var control = 0
        for b in sample {
            if b == 0 { return false }                          // null byte → binary
            if b < 9 || (b > 13 && b < 32) { control += 1 }     // odd control chars
        }
        return Double(control) / Double(sample.count) < 0.06
    }
}

private struct DiagonalStripes: View {
    var body: some View {
        Canvas { ctx, size in
            let dark = Color(hex: 0x0D0A06)
            let light = Color(hex: 0x171008)
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(dark))
            let step: CGFloat = 28
            var x = -size.height
            while x < size.width + size.height {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x + 14, y: 0))
                p.addLine(to: CGPoint(x: x + 14 + size.height, y: size.height))
                p.addLine(to: CGPoint(x: x + size.height, y: size.height))
                p.closeSubpath()
                ctx.fill(p, with: .color(light))
                x += step
            }
        }
    }
}

private struct ActionButton: View {
    let label: String
    let bg: Color
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(label).lcars(14, .bold, tracking: 1.5, color: LC.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(bg))
                .brightness(hovering ? 0.06 : 0)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
