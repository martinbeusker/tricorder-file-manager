import SwiftUI

// Shared grid geometry for header + rows
private let cols: [GridItem] = [
    GridItem(.fixed(36), spacing: 6, alignment: .leading),
    GridItem(.flexible(minimum: 100), spacing: 6, alignment: .leading),
    GridItem(.fixed(72), spacing: 6, alignment: .leading),
    GridItem(.fixed(84), spacing: 6, alignment: .leading),
    GridItem(.fixed(92), spacing: 6, alignment: .leading),
]

struct FileListView: View {
    @ObservedObject var model: FileSystemModel
    @FocusState.Binding var focus: FocusField?

    var body: some View {
        VStack(spacing: 8) {
            SearchBar(model: model, focus: $focus)
            header
            list
        }
    }

    private func arrow(_ key: SortKey) -> String {
        guard model.sortKey == key else { return "" }
        return model.sortAscending ? " \u{25B4}" : " \u{25BE}"
    }

    /// For a nested recursive-search result, the path relative to the search root.
    private func pathHint(for item: FileItem) -> String? {
        guard let rp = model.relativePath(for: item), rp.contains("/") else { return nil }
        return rp
    }

    private var header: some View {
        LazyVGrid(columns: cols, alignment: .leading, spacing: 0) {
            Color.clear.frame(height: 1)
            headerButton("NAME", .name)
            headerButton("TYPE", .kind)
            headerButton("SIZE", .size)
            headerButton("MODIFIED", .date)
        }
    }

    private func headerButton(_ label: String, _ key: SortKey) -> some View {
        LCARSButton(title: label + arrow(key),
                    bg: model.sortKey == key ? LC.cream : LC.brownButton,
                    fg: LC.black, size: 13, weight: .bold, tracking: 1.2,
                    radius: 13, padH: 12, padV: 6, align: .leading) {
            model.sortBy(key)
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.visibleItems.enumerated()), id: \.element.url) { idx, item in
                        FileRow(item: item,
                                index: idx + 1,
                                selected: item.url == model.selectedID,
                                compact: model.compact,
                                pathHint: pathHint(for: item))
                            .id(item.url)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) { model.open(item) }
                            .onTapGesture { model.select(item) }
                    }
                    if model.searchTruncated {
                        Text("SHOWING FIRST \(SearchWalker.maxMatches) MATCHES")
                            .lcars(13, .semibold, tracking: 1.5, color: LC.brownButton)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    }
                    if model.isFiltering && model.visibleItems.isEmpty {
                        Text(model.searching ? "SCANNING SUBSPACE\u{2026}"
                                             : "NO RECORDS MATCH \u{201C}\(model.trimmedQuery.uppercased())\u{201D}")
                            .lcars(15, .semibold, tracking: 1.5, color: LC.brownButton)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 40)
                    }
                }
                .padding(.trailing, 4)
            }
            .modifier(NavIntro(tick: model.navTick, motion: model.motion))
            .onChange(of: model.selectedID) { _, sel in
                if let sel { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(sel, anchor: .center) } }
            }
        }
    }
}

// MARK: - LCARS search field
struct SearchBar: View {
    @ObservedObject var model: FileSystemModel
    @FocusState.Binding var focus: FocusField?

    var body: some View {
        HStack(spacing: 6) {
            Text("SEARCH").lcars(13, .bold, tracking: 1.2, color: LC.black)
                .padding(.horizontal, 14)
                .frame(maxHeight: .infinity)
                .background(UnevenRoundedRectangle(topLeadingRadius: 13, bottomLeadingRadius: 13).fill(LC.amber))

            ZStack(alignment: .leading) {
                if model.query.isEmpty {
                    Text("SEARCH THIS FOLDER + ALL SUBFOLDERS…")
                        .lcars(14, .medium, tracking: 1, color: LC.brownButton)
                }
                TextField("", text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.antonio(15, .medium))
                    .foregroundColor(LC.txt)
                    .tint(LC.amber)
                    .focused($focus, equals: .search)
                    .onSubmit {
                        // Enter opens the top hit: descend into a folder, or select a file.
                        if let first = model.visibleItems.first {
                            if first.isDir { model.open(first) }
                            else { model.select(first); model.clearSearch(); focus = .list }
                        }
                    }
                    .onKeyPress(.escape) { model.clearSearch(); focus = .list; return .handled }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .frame(maxHeight: .infinity)
            .background(Color(hex: 0x1A1206))

            if !model.query.isEmpty {
                Button { model.clearSearch(); focus = .search } label: {
                    Text("\u{00D7}").lcars(18, .bold, color: LC.black)
                        .frame(width: 34).frame(maxHeight: .infinity)
                        .background(LC.salmon)
                }
                .buttonStyle(.plain)
            }

            UnevenRoundedRectangle(bottomTrailingRadius: 13, topTrailingRadius: 13)
                .fill(LC.brownButton).frame(width: 14)
        }
        .frame(height: 34)
    }
}

// MARK: - One file row
struct FileRow: View {
    let item: FileItem
    let index: Int
    let selected: Bool
    let compact: Bool
    var pathHint: String? = nil
    @State private var hovering = false

    private var fg: Color { selected ? LC.black : LC.txt }
    private var dim: Color { selected ? LC.black.opacity(0.7) : LC.dim }

    private var sizeLabel: String {
        item.isDir ? "\(item.childCount ?? 0) OBJ" : Fmt.bytes(item.size)
    }

    var body: some View {
        LazyVGrid(columns: cols, alignment: .leading, spacing: 0) {
            Text(String(format: "%02d", index)).lcars(14, .semibold, tracking: 1, color: dim)

            // recursive results show their relative path (head-truncated so the
            // filename stays visible); plain listings just show the name.
            Text(pathHint ?? item.name)
                .lcars(pathHint == nil ? 17 : 15, .medium, tracking: 0.8, color: fg)
                .lineLimit(1)
                .truncationMode(pathHint == nil ? .tail : .head)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.kind.label).lcars(12, .bold, tracking: 1, color: LC.black)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(Capsule().fill(item.kind.color))

            Text(sizeLabel).lcars(15, .medium, tracking: 0.6, color: dim)
            Text(Fmt.date(item.modified)).lcars(15, .medium, tracking: 0.6, color: dim)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 4 : 9)
        .background(selected ? LC.amber : (hovering ? LC.amber.opacity(0.16) : .clear))
        .overlay(Rectangle().fill(LC.amber.opacity(0.14)).frame(height: 1), alignment: .bottom)
        .onHover { hovering = $0 }
    }
}

// MARK: - Replay the panel-in animation on navigation
private struct NavIntro: ViewModifier {
    let tick: Int
    let motion: Bool
    @State private var shown = true

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(x: shown ? 0 : 16)
            .onChange(of: tick) { _, _ in
                guard motion else { shown = true; return }
                shown = false
                withAnimation(.easeOut(duration: 0.3)) { shown = true }
            }
    }
}
