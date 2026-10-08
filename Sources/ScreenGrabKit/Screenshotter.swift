import Foundation

public enum Screenshotter {

    /// Captures the device's default display to `destination` (must end in .png).
    /// `maskCorners` gives simulator screenshots transparent rounded corners; physical devices ignore it.
    public static func capture(_ device: Device, to destination: URL, maskCorners: Bool = false) async throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        let output = switch device.source {
            case .physical:
                try await Devicectl.run(["device", "capture", "screenshot", "--device", device.udid, "--destination", destination.path])
            case .simulator:
                // Without an explicit mask simctl already writes alpha corners; `ignored` matches device captures.
                try await Simctl.run(["io", device.udid, "screenshot", "--type=png", "--mask=\(maskCorners ? "alpha" : "ignored")", destination.path])
        }
        guard output.status == 0 else { throw CaptureError.classify(output: output.text) }

        let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int) ?? 0
        guard size > 0 else { throw CaptureError.failed("no image was written") }
    }
}
