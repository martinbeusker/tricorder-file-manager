import SwiftUI

// MARK: - File kind → LCARS tag color + label
enum FileKind: Equatable {
    case dir, img, vid, aud, doc, data, db, code, archive, app
    case other(String)

    var label: String {
        switch self {
        case .dir:     return "DIR"
        case .img:     return "IMG"
        case .vid:     return "VID"
        case .aud:     return "AUD"
        case .doc:     return "DOC"
        case .data:    return "DATA"
        case .db:      return "DB"
        case .code:    return "CODE"
        case .archive: return "ARCV"
        case .app:     return "APP"
        case .other(let ext):
            return ext.isEmpty ? "FILE" : String(ext.uppercased().prefix(5))
        }
    }

    var color: Color {
        switch self {
        case .dir:                return LC.amber
        case .doc, .other:        return LC.cream
        case .data, .code, .archive: return LC.salmon
        case .vid, .aud:          return LC.orange
        case .db, .img, .app:     return LC.plum
        }
    }

    /// Human-readable line for the FILE RECORD panel.
    var recordName: String {
        switch self {
        case .dir: return "DIRECTORY"
        case .app: return "APPLICATION"
        default:   return label + " FILE"
        }
    }

    static func fromExtension(_ ext: String) -> FileKind {
        switch ext.lowercased() {
        case "png","jpg","jpeg","gif","heic","heif","tiff","tif","bmp","webp","svg","icns","raw":
            return .img
        case "mov","mp4","m4v","avi","mkv","webm","mpg","mpeg","wmv","flv":
            return .vid
        case "mp3","wav","aac","m4a","flac","aiff","aif","ogg","caf","alac":
            return .aud
        case "txt","md","markdown","rtf","rtfd","pdf","doc","docx","pages","key","ppt","pptx","xls","xlsx","numbers","odt","tex":
            return .doc
        case "dat","csv","tsv","json","xml","yaml","yml","log","plist","bin","toml","ini","conf":
            return .data
        case "db","sqlite","sqlite3","sql","realm","mdb":
            return .db
        case "swift","js","mjs","cjs","ts","jsx","tsx","py","rb","go","rs","c","cc","cpp","h","hpp","hh","java","kt","cs","php","sh","zsh","bash","html","htm","css","scss","sass","lua","pl","r","m","mm":
            return .code
        case "zip","tar","gz","tgz","bz2","xz","7z","rar","dmg","pkg","iso","jar","war":
            return .archive
        default:
            return .other(ext)
        }
    }
}

// MARK: - A single row in the file list
struct FileItem: Identifiable, Hashable {
    let url: URL
    let name: String
    let isDir: Bool          // real directory the user can descend into (packages excluded)
    let size: Int64          // bytes (files only)
    let modified: Date?
    let childCount: Int?     // directories only

    var id: URL { url }
    var ext: String { url.pathExtension }

    var kind: FileKind {
        if isDir { return .dir }
        if url.pathExtension.lowercased() == "app" { return .app }
        return FileKind.fromExtension(url.pathExtension)
    }

    static func == (a: FileItem, b: FileItem) -> Bool { a.url == b.url }
    func hash(into h: inout Hasher) { h.combine(url) }
}

// MARK: - Formatting helpers
enum Fmt {
    static func bytes(_ b: Int64) -> String {
        if b < 0 { return "—" }
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var v = Double(b); var i = 0
        while v >= 1000 && i < units.count - 1 { v /= 1000; i += 1 }
        if i == 0 { return "\(b) B" }
        return String(format: v < 10 ? "%.1f %@" : "%.0f %@", v, units[i])
    }

    static func date(_ d: Date?) -> String {
        guard let d else { return "—" }
        return isoDay.string(from: d)
    }

    private static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// The design's name checksum, preserved for flavor (JS: h = h*31 + code >>> 0).
    static func checksum(_ name: String) -> String {
        var h: UInt32 = 7
        for u in name.utf16 { h = h &* 31 &+ UInt32(u) }
        return String(format: "%06X", h % 0xFFFFFF)
    }
}
