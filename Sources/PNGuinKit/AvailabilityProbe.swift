import Foundation

/// Determines whether a device can be captured right now via `devicectl device info lockState`.
/// (`tunnelState` in the device list only reflects the most recently used tunnel, not reachability.)
enum AvailabilityProbe {

    static func classify(status: Int32, output: String, json: Data?) -> Device.Availability {
        guard status == 0 else {
            if case .locked = CaptureError.classify(output: output) { return .locked }
            return .unreachable
        }
        guard
            let json,
            let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
            let result = root["result"] as? [String: Any]
        else { return .unreachable }
        return result["passcodeRequired"] as? Bool == true ? .locked : .ready
    }

    static func probe(udid: String) async -> Device.Availability {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("pnguin-lock-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }

        guard let output = try? await Devicectl.run(["device", "info", "lockState", "--device", udid, "--timeout", "5", "--quiet", "--json-output", file.path]) else {
            return .unreachable
        }
        return classify(status: output.status, output: output.text, json: try? Data(contentsOf: file))
    }
}
