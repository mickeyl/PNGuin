import Foundation

public enum OutputLocation {

    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }

    public static func fileName(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return "iphone-screenshot-\(formatter.string(from: date)).png"
    }

    public static func normalized(name: String) -> String {
        name.lowercased().hasSuffix(".png") ? name : name + ".png"
    }

    /// Appends -1, -2, … so rapid consecutive captures never overwrite each other.
    public static func uniqueURL(directory: URL, name: String, fileManager: FileManager = .default) -> URL {
        let candidate = directory.appendingPathComponent(name)
        guard fileManager.fileExists(atPath: candidate.path) else { return candidate }

        let base = candidate.deletingPathExtension().lastPathComponent
        var index = 1
        while true {
            let next = directory.appendingPathComponent("\(base)-\(index).png")
            if !fileManager.fileExists(atPath: next.path) { return next }
            index += 1
        }
    }
}
