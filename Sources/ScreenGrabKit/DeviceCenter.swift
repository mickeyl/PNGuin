import Foundation

public enum DeviceCenter {

    /// Physical iPhones and iPads known to CoreDevice, sorted by name; availability is `.unknown`.
    public static func devices() async throws -> [Device] {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("screengrab-devices-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }

        let output = try await Devicectl.run(["list", "devices", "--quiet", "--json-output", file.path])
        guard output.status == 0 else { throw CaptureError.classify(output: output.text) }
        guard let data = try? Data(contentsOf: file) else { throw CaptureError.unexpectedOutput("no JSON written") }

        return try DeviceList.parse(data).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Probes all devices in parallel (~0.6 s for reachable ones, bounded by a 5 s timeout otherwise).
    public static func probed(_ devices: [Device]) async -> [Device] {
        await withTaskGroup(of: (Int, Device.Availability).self) { group in
            for (index, device) in devices.enumerated() {
                group.addTask { (index, await AvailabilityProbe.probe(udid: device.udid)) }
            }
            var result = devices
            for await (index, availability) in group { result[index].availability = availability }
            return result
        }
    }

    public static func probe(_ device: Device) async -> Device {
        var copy = device
        copy.availability = await AvailabilityProbe.probe(udid: device.udid)
        return copy
    }
}
