import Foundation

public enum DeviceSelector {

    /// Resolves a user-provided name/UDID, or the only ready device when no query is given.
    /// Without a query the devices must have been probed, see `DeviceCenter.probed()`.
    public static func resolve(query: String?, in devices: [Device]) throws -> Device {
        if let query, !query.isEmpty {
            let matches = devices.filter {
                $0.udid.caseInsensitiveCompare(query) == .orderedSame || $0.name.caseInsensitiveCompare(query) == .orderedSame
            }
            switch matches.count {
                case 0: throw CaptureError.notFound(query: query)
                case 1: return matches[0]
                default: throw CaptureError.ambiguous(candidates: matches.map(\.name))
            }
        }

        let ready = devices.filter(\.isReady)
        switch ready.count {
            case 0: throw devices.filter { $0.availability == .locked }.count == 1 ? CaptureError.locked : CaptureError.noDevice
            case 1: return ready[0]
            default: throw CaptureError.ambiguous(candidates: ready.map(\.name))
        }
    }
}
