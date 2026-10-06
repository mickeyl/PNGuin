import Foundation

/// Previews live in the user cache, never in the output folder, so opening the menu leaves no files behind.
public enum PreviewCache {

    public static var directory: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ScreenGrab/previews", isDirectory: true)
    }

    public static func url(for udid: String) -> URL {
        directory.appendingPathComponent("\(udid).png")
    }

    public static func capture(udid: String) async throws -> URL {
        let target = url(for: udid)
        let staging = directory.appendingPathComponent("\(udid)-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: staging) }

        try await Screenshotter.capture(udid: udid, to: staging)
        if FileManager.default.fileExists(atPath: target.path) {
            _ = try FileManager.default.replaceItemAt(target, withItemAt: staging)
        } else {
            try FileManager.default.moveItem(at: staging, to: target)
        }
        return target
    }
}
