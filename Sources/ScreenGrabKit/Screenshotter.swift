import Foundation

public enum Screenshotter {

    /// Captures the device's default display to `destination` (must end in .png).
    public static func capture(udid: String, to destination: URL) async throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        let output = try await Devicectl.run(["device", "capture", "screenshot", "--device", udid, "--destination", destination.path])
        guard output.status == 0 else { throw CaptureError.classify(output: output.text) }

        let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int) ?? 0
        guard size > 0 else { throw CaptureError.failed("devicectl wrote no image") }
    }
}
