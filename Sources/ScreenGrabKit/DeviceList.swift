import Foundation

/// Parses the JSON written by `devicectl list devices --json-output`.
/// The schema is not a documented contract, so every field is read defensively.
public enum DeviceList {

    public static func parse(_ data: Data) throws -> [Device] {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let result = root["result"] as? [String: Any],
            let entries = result["devices"] as? [[String: Any]]
        else {
            throw CaptureError.unexpectedOutput("device list has no result.devices")
        }
        return entries.compactMap(device(from:))
    }

    private static func device(from entry: [String: Any]) -> Device? {
        let hardware = entry["hardwareProperties"] as? [String: Any] ?? [:]
        let properties = entry["deviceProperties"] as? [String: Any] ?? [:]

        guard
            hardware["reality"] as? String == "physical",
            let kind = (hardware["deviceType"] as? String).flatMap(Device.Kind.init(rawValue:)),
            let udid = hardware["udid"] as? String,
            let name = properties["name"] as? String
        else { return nil }

        return Device(name: name, udid: udid, kind: kind, osVersion: properties["osVersionNumber"] as? String)
    }
}
