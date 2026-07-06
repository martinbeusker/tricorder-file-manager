import SwiftUI
import AppKit

enum SortKey: String { case name, kind, size, date }

@MainActor
final class FileSystemModel: ObservableObject {

    // Location + contents
    @Published private(set) var currentURL: URL
    @Published private(set) var items: [FileItem] = []
    @Published var selectedID: URL? = nil

    // Sorting
    @Published private(set) var sortKey: SortKey = .name
    @Published private(set) var sortAscending = true

    // Transient status line (design's `flash`)
    @Published private(set) var status: String? = nil

    // Volume usage for the STORAGE meter / footer
    @Published private(set) var diskFree: Int64 = 0
    @Published private(set) var diskTotal: Int64 = 0

    // Bumped on every navigation so the list can replay its intro animation
    @Published private(set) var navTick: Int = 0

    // Behaviour props exposed by the original component
    @Published var motion = true
    @Published var redAlert = false
    @Published var compact = false

    // Search — recursive over the subtree rooted at the current directory
    @Published var query = ""
    @Published private(set) var searchFocusRequests = 0
    @Published private(set) var searchResults: [FileItem]? = nil   // nil until the walk emits
    @Published private(set) var searching = false
    @Published private(set) var searchTruncated = false
    private var searchTask: Task<Void, Never>?

    let home = FileManager.default.homeDirectoryForCurrentUser
    private var backStack: [URL] = []
    private var flashItem: DispatchWorkItem?

    init() {
        currentURL = FileManager.default.homeDirectoryForCurrentUser
        reload()
    }

    // MARK: Derived

    var sortedItems: [FileItem] {
        items.sorted { a, b in
            if a.isDir != b.isDir { return a.isDir }          // folders first
            let order: Bool
            switch sortKey {
            case .name: order = a.name.localizedStandardCompare(b.name) == .orderedAscending
            case .kind: order = a.kind.label == b.kind.label
                ? a.name.localizedStandardCompare(b.name) == .orderedAscending
                : a.kind.label < b.kind.label
            case .size:
                let sa = a.isDir ? Int64(a.childCount ?? 0) : a.size
                let sb = b.isDir ? Int64(b.childCount ?? 0) : b.size
                order = sa == sb ? a.name.localizedStandardCompare(b.name) == .orderedAscending : sa < sb
            case .date:
                let da = a.modified ?? .distantPast
                let db = b.modified ?? .distantPast
                order = da == db ? a.name.localizedStandardCompare(b.name) == .orderedAscending : da < db
            }
            return sortAscending ? order : !order
        }
    }

    var selected: FileItem? {
        guard let s = selectedID else { return nil }
        return items.first { $0.url == s } ?? searchResults?.first { $0.url == s }
    }

    var trimmedQuery: String { query.trimmingCharacters(in: .whitespaces) }
    var isFiltering: Bool { !trimmedQuery.isEmpty }

    /// The rows to show: the recursive results once available, else an instant
    /// current-directory filter while the walk spins up.
    var visibleItems: [FileItem] {
        guard isFiltering else { return sortedItems }
        if let r = searchResults { return r }
        let q = trimmedQuery.lowercased()
        return sortedItems.filter { $0.name.lowercased().contains(q) }
    }

    /// Path of a result relative to the search root (nil when not a nested result).
    func relativePath(for item: FileItem) -> String? {
        guard isFiltering, searchResults != nil else { return nil }
        let base = currentURL.standardizedFileURL.path
        let prefix = base.hasSuffix("/") ? base : base + "/"
        let p = item.url.standardizedFileURL.path
        return p.hasPrefix(prefix) ? String(p.dropFirst(prefix.count)) : item.name
    }

    func requestSearchFocus() { searchFocusRequests &+= 1 }
    func clearSearch() { query = "" }

    // MARK: Recursive search driver

    /// Called whenever the query text changes (debounced, cancellable).
    func searchQueryChanged() {
        searchTask?.cancel()
        guard isFiltering else {
            searchResults = nil; searching = false; searchTruncated = false; return
        }
        searchResults = nil
        searchTruncated = false
        searching = true
        let q = trimmedQuery.lowercased()
        let root = currentURL
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)      // debounce keystrokes
            if Task.isCancelled { return }
            for await update in SearchWalker.stream(root: root, query: q) {
                if Task.isCancelled { return }
                guard let self, self.currentURL == root,
                      self.trimmedQuery.lowercased() == q else { return }
                self.searchResults = update.items
                if update.truncated { self.searchTruncated = true }
                if update.done { self.searching = false }
            }
            if let self, !Task.isCancelled, self.currentURL == root,
               self.trimmedQuery.lowercased() == q { self.searching = false }
        }
    }

    private func cancelSearch() {
        searchTask?.cancel()
        searchResults = nil
        searching = false
        searchTruncated = false
    }

    var canGoUp: Bool { currentURL.pathComponents.count > 1 }
    var canGoBack: Bool { !backStack.isEmpty }

    /// Breadcrumb chips: MAIN (home) + descent, or the absolute path when outside home.
    var crumbs: [(label: String, url: URL)] {
        var out: [(String, URL)] = []
        let homePath = home.standardizedFileURL.path
        let curPath  = currentURL.standardizedFileURL.path
        if curPath == homePath || curPath.hasPrefix(homePath + "/") {
            out.append(("MAIN", home))
            let rest = curPath == homePath ? "" : String(curPath.dropFirst(homePath.count + 1))
            var acc = home
            for seg in rest.split(separator: "/") {
                acc.appendPathComponent(String(seg))
                out.append((seg.uppercased(), acc))
            }
        } else {
            var acc = URL(fileURLWithPath: "/")
            out.append(("/", acc))
            for seg in currentURL.pathComponents where seg != "/" {
                acc.appendPathComponent(seg)
                out.append((seg.uppercased(), acc))
            }
        }
        return out.map { ($0.0, $0.1) }
    }

    /// Human-readable path labels for any URL (used by the FILE RECORD panel, which
    /// may show a nested search result that isn't in the current directory).
    func pathLabels(for url: URL) -> [String] {
        let homePath = home.standardizedFileURL.path
        let p = url.standardizedFileURL.path
        if p == homePath || p.hasPrefix(homePath + "/") {
            var out = ["MAIN"]
            let rest = p == homePath ? "" : String(p.dropFirst(homePath.count + 1))
            out += rest.split(separator: "/").map { $0.uppercased() }
            return out
        }
        return ["/"] + url.pathComponents.filter { $0 != "/" }.map { $0.uppercased() }
    }

    /// Quick-access rail: MAIN STORAGE + standard user folders that exist.
    var railItems: [(label: String, url: URL)] {
        var out: [(String, URL)] = [("MAIN STORAGE", home)]
        let fm = FileManager.default
        let candidates: [(String, FileManager.SearchPathDirectory)] = [
            ("DESKTOP", .desktopDirectory),
            ("DOCUMENTS", .documentDirectory),
            ("DOWNLOADS", .downloadsDirectory),
            ("PICTURES", .picturesDirectory),
            ("APPLICATIONS", .applicationDirectory),
        ]
        for (label, dir) in candidates {
            if let u = fm.urls(for: dir, in: .userDomainMask).first, fm.fileExists(atPath: u.path) {
                out.append((label, u))
            } else if dir == .applicationDirectory {
                out.append((label, URL(fileURLWithPath: "/Applications")))
            }
        }
        return out
    }

    /// Which rail item is currently active (deepest ancestor of currentURL).
    func railActive(_ url: URL) -> Bool {
        let cur = currentURL.standardizedFileURL.path
        let base = url.standardizedFileURL.path
        let isDescendant = cur == base || cur.hasPrefix(base + "/")
        guard isDescendant else { return false }
        // Only the most specific matching rail entry lights up.
        let deeper = railItems.contains { other in
            let ob = other.url.standardizedFileURL.path
            return ob != base && ob.count > base.count &&
                   (cur == ob || cur.hasPrefix(ob + "/"))
        }
        return !deeper
    }

    var usedFraction: Double {
        guard diskTotal > 0 else { return 0 }
        return Double(diskTotal - diskFree) / Double(diskTotal)
    }

    // MARK: Navigation

    func navigate(to url: URL, pushHistory: Bool = true) {
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            flash("PATH UNAVAILABLE"); return
        }
        if pushHistory && url.standardizedFileURL != currentURL.standardizedFileURL {
            backStack.append(currentURL)
        }
        currentURL = url.standardizedFileURL
        selectedID = nil
        query = ""                       // a fresh directory starts unfiltered
        navTick &+= 1
        reload()
    }

    func goBack() {
        guard let prev = backStack.popLast() else { return }
        navigate(to: prev, pushHistory: false)
    }

    func goUp() {
        guard canGoUp else { return }
        navigate(to: currentURL.deletingLastPathComponent())
    }

    func goHome() { navigate(to: home) }

    // MARK: Sorting / selection

    func sortBy(_ key: SortKey) {
        if sortKey == key { sortAscending.toggle() }
        else { sortKey = key; sortAscending = true }
    }

    func select(_ item: FileItem) { selectedID = item.url }

    func moveSelection(_ delta: Int) {
        let list = visibleItems
        guard !list.isEmpty else { return }
        guard let cur = selectedID, let idx = list.firstIndex(where: { $0.url == cur }) else {
            selectedID = list.first?.url; return
        }
        let next = min(max(idx + delta, 0), list.count - 1)
        selectedID = list[next].url
    }

    // MARK: Operations

    func open(_ item: FileItem) {
        if item.isDir { navigate(to: item.url) }
        else {
            NSWorkspace.shared.open(item.url)
            flash("OPENING · \(item.name.uppercased())")
        }
    }

    func openSelected() { if let s = selected { open(s) } }

    func copySelected() {
        guard let item = selected else { flash("NO RECORD SELECTED"); return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([item.url as NSURL])
        flash("COPIED TO CLIPBOARD")
    }

    func revealSelected() {
        guard let item = selected else { flash("NO RECORD SELECTED"); return }
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func moveSelected() {
        guard let item = selected else { flash("NO RECORD SELECTED"); return }
        let panel = NSOpenPanel()
        panel.title = "Relocate \(item.name)"
        panel.prompt = "Move Here"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = currentURL
        guard panel.runModal() == .OK, let dest = panel.url else { return }
        let target = dest.appendingPathComponent(item.name)
        if target.standardizedFileURL == item.url.standardizedFileURL { return }
        do {
            try FileManager.default.moveItem(at: item.url, to: target)
            selectedID = nil
            reload()
            if isFiltering { searchQueryChanged() }
            flash("MOVED · \(dest.lastPathComponent.uppercased())")
        } catch {
            flash("MOVE FAILED")
        }
    }

    func purgeSelected() {
        guard let item = selected else { flash("NO RECORD SELECTED"); return }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Purge “\(item.name)”?"
        alert.informativeText = "The record will be moved to the Trash."
        alert.addButton(withTitle: "Purge")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            selectedID = nil
            reload()
            if isFiltering { searchQueryChanged() }
            flash("RECORD PURGED")
        } catch {
            flash("PURGE FAILED")
        }
    }

    // MARK: Status flash

    func flash(_ msg: String) {
        flashItem?.cancel()
        status = msg
        let work = DispatchWorkItem { [weak self] in self?.status = nil }
        flashItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    // MARK: Directory read

    func reload() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .isDirectoryKey, .isPackageKey, .fileSizeKey, .totalFileSizeKey,
            .contentModificationDateKey,
        ]
        var result: [FileItem] = []
        if let urls = try? fm.contentsOfDirectory(at: currentURL,
                                                  includingPropertiesForKeys: keys,
                                                  options: [.skipsHiddenFiles]) {
            for u in urls {
                let v = try? u.resourceValues(forKeys: Set(keys))
                let isPackage = v?.isPackage ?? false
                let rawDir = v?.isDirectory ?? false
                let isDir = rawDir && !isPackage
                let size = Int64(v?.totalFileSize ?? v?.fileSize ?? 0)
                let mod = v?.contentModificationDate
                var childCount: Int? = nil
                if isDir {
                    childCount = (try? fm.contentsOfDirectory(atPath: u.path).count)
                }
                result.append(FileItem(url: u.standardizedFileURL,
                                       name: u.lastPathComponent,
                                       isDir: isDir,
                                       size: size,
                                       modified: mod,
                                       childCount: childCount))
            }
        }
        items = result
        if let sel = selectedID, !result.contains(where: { $0.url == sel }) {
            selectedID = nil
        }
        refreshDiskUsage()
    }

    private func refreshDiskUsage() {
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey,
        ]
        if let v = try? currentURL.resourceValues(forKeys: keys) {
            diskFree  = Int64(v.volumeAvailableCapacityForImportantUsage ?? 0)
            diskTotal = Int64(v.volumeTotalCapacity ?? 0)
        }
    }
}
