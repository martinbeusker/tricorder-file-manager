import Foundation

/// Breadth-first, cancellable recursive file search that streams partial results.
/// Runs its IO on a detached task so the UI never blocks; the consumer just awaits
/// batches and publishes them.
enum SearchWalker {
    static let keys: [URLResourceKey] = [
        .isDirectoryKey, .isPackageKey, .fileSizeKey, .totalFileSizeKey, .contentModificationDateKey,
    ]
    static let maxMatches = 500          // cap results (keeps the list + memory bounded)
    static let maxVisited = 300_000      // cap traversal so rare queries can't run forever
    static let skipDirs: Set<String> = ["node_modules", ".Trash", ".git"]

    struct Update: Sendable {
        let items: [FileItem]
        let truncated: Bool
        let done: Bool
    }

    static func stream(root: URL, query: String) -> AsyncStream<Update> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                let fm = FileManager.default
                var matches: [FileItem] = []
                var queue: [URL] = [root]      // BFS → shallow matches surface first
                var visited = 0
                var lastEmitted = 0

                while !queue.isEmpty {
                    if Task.isCancelled { continuation.finish(); return }
                    let dir = queue.removeFirst()
                    guard let entries = try? fm.contentsOfDirectory(
                        at: dir, includingPropertiesForKeys: keys,
                        options: [.skipsHiddenFiles]) else { continue }

                    let sorted = entries.sorted {
                        $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
                    }
                    for u in sorted {
                        if Task.isCancelled { continuation.finish(); return }
                        visited += 1
                        let v = try? u.resourceValues(forKeys: Set(keys))
                        let isPkg = v?.isPackage ?? false
                        let isDir = (v?.isDirectory ?? false) && !isPkg
                        let name = u.lastPathComponent

                        if name.lowercased().contains(query) {
                            var childCount: Int? = nil
                            if isDir { childCount = (try? fm.contentsOfDirectory(atPath: u.path).count) }
                            matches.append(FileItem(
                                url: u.standardizedFileURL, name: name, isDir: isDir,
                                size: Int64(v?.totalFileSize ?? v?.fileSize ?? 0),
                                modified: v?.contentModificationDate, childCount: childCount))
                            if matches.count >= maxMatches {
                                continuation.yield(Update(items: matches, truncated: true, done: true))
                                continuation.finish(); return
                            }
                        }
                        if isDir && !skipDirs.contains(name) { queue.append(u) }
                    }

                    if visited > maxVisited {
                        continuation.yield(Update(items: matches, truncated: true, done: true))
                        continuation.finish(); return
                    }
                    if matches.count != lastEmitted {          // only emit when there's something new
                        lastEmitted = matches.count
                        continuation.yield(Update(items: matches, truncated: false, done: false))
                    }
                }
                continuation.yield(Update(items: matches, truncated: false, done: true))
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
