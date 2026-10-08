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

    public static func capture(_ device: Device, maskCorners: Bool = false) async throws -> URL {
        let target = url(for: device.udid)
        let staging = directory.appendingPathComponent("\(device.udid)-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: staging) }

        try await Screenshotter.capture(device, to: staging, maskCorners: maskCorners)
        if FileManager.default.fileExists(atPath: target.path) {
            _ = try FileManager.default.replaceItemAt(target, withItemAt: staging)
        } else {
            try FileManager.default.moveItem(at: staging, to: target)
        }
        return target
    }

    /// Copies the preview under a regular screenshot name, so a drag hands out a sensibly named file.
    /// Only the latest drag needs its file (drop targets copy it), so older ones are discarded.
    public static func exportedCopy(udid: String) throws -> URL {
        let exports = FileManager.default.temporaryDirectory.appendingPathComponent("ScreenGrab-drag", isDirectory: true)
        try? FileManager.default.removeItem(at: exports)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)

        let target = exports.appendingPathComponent(OutputLocation.fileName())
        try FileManager.default.copyItem(at: url(for: udid), to: target)
        return target
    }
}
