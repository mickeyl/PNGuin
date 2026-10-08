import Foundation

/// Parses the JSON printed by `simctl list -j`. Like devicectl's, the schema is not a documented contract.
public enum SimulatorList {

    /// Booted, available iPhone and iPad simulators; they are always `.ready`.
    public static func parse(_ data: Data) throws -> [Device] {
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let runtimes = root["devices"] as? [String: Any]
        else {
            throw CaptureError.unexpectedOutput("simulator list has no devices")
        }
        let families = productFamilies(root["devicetypes"] as? [[String: Any]] ?? [])
        let versions = iOSVersions(root["runtimes"] as? [[String: Any]] ?? [])

        return runtimes.flatMap { runtime, entries -> [Device] in
            guard let version = versions[runtime] ?? fallbackVersion(runtime: runtime) else { return [] }
            return (entries as? [[String: Any]] ?? []).compactMap { device(from: $0, osVersion: version, families: families) }
        }
    }

    private static func device(from entry: [String: Any], osVersion: String, families: [String: String]) -> Device? {
        guard
            entry["state"] as? String == "Booted",
            entry["isAvailable"] as? Bool != false,
            let udid = entry["udid"] as? String,
            let name = entry["name"] as? String,
            let type = entry["deviceTypeIdentifier"] as? String,
            let kind = Device.Kind(rawValue: families[type] ?? fallbackFamily(type: type))
        else { return nil }

        return Device(name: name, udid: udid, kind: kind, osVersion: osVersion, source: .simulator, availability: .ready)
    }

    private static func productFamilies(_ types: [[String: Any]]) -> [String: String] {
        let pairs = types.compactMap { type -> (String, String)? in
            guard let identifier = type["identifier"] as? String, let family = type["productFamily"] as? String else { return nil }
            return (identifier, family)
        }
        return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    }

    /// iPad simulators run the iOS runtime too, so filtering on it drops watchOS, tvOS and visionOS.
    private static func iOSVersions(_ runtimes: [[String: Any]]) -> [String: String] {
        let pairs = runtimes.compactMap { runtime -> (String, String)? in
            guard
                runtime["platform"] as? String == "iOS",
                let identifier = runtime["identifier"] as? String,
                let version = runtime["version"] as? String
            else { return nil }
            return (identifier, version)
        }
        return Dictionary(pairs, uniquingKeysWith: { first, _ in first })
    }

    /// `com.apple.CoreSimulator.SimRuntime.iOS-27-0` → `27.0`, for runtimes missing from the `runtimes` section.
    private static func fallbackVersion(runtime: String) -> String? {
        guard let range = runtime.range(of: "SimRuntime.iOS-") else { return nil }
        return runtime[range.upperBound...].replacingOccurrences(of: "-", with: ".")
    }

    private static func fallbackFamily(type: String) -> String {
        switch type {
            case _ where type.contains(".iPad"): Device.Kind.iPad.rawValue
            case _ where type.contains(".iPhone"): Device.Kind.iPhone.rawValue
            default: ""
        }
    }
}
