import ScreenGrabKit

/// Physical devices: lists them, then probes one at a time, because overlapping probes wedge CoreDevice
/// (see `DeviceCenter.probed`). Every change is published as it happens.
enum DeviceMonitor {

    static let interval: Duration = .seconds(5)

    /// One pass. `current` returns the last published list; it carries availability over (so rows don't flash back
    /// to "Checking…") and lets the selected device be probed first.
    static func refresh(current: () -> [Device], selected: String?, publish: ([Device]) -> Void) async throws {
        let listed = try await DeviceCenter.devices()
        let known = Dictionary(current().map { ($0.udid, $0.availability) }, uniquingKeysWith: { first, _ in first })
        publish(listed.map { device in
            var device = device
            device.availability = known[device.udid] ?? .unknown
            return device
        })

        let devices = current()
        let order = devices.filter { $0.udid == selected } + devices.filter { $0.udid != selected }
        for device in order {
            let availability = await DeviceCenter.probe(device).availability
            guard !Task.isCancelled else { return }
            var updated = current()
            guard let index = updated.firstIndex(where: { $0.udid == device.udid }), updated[index].availability != availability else { continue }
            updated[index].availability = availability
            publish(updated)
        }
    }
}
