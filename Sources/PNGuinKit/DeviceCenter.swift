import Foundation

public enum DeviceCenter {

    /// Physical iPhones and iPads known to CoreDevice, sorted by name; availability is `.unknown`.
    public static func devices() async throws -> [Device] {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("pnguin-devices-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }

        let output = try await Devicectl.run(["list", "devices", "--quiet", "--json-output", file.path])
        guard output.status == 0 else { throw CaptureError.classify(output: output.text) }
        guard let data = try? Data(contentsOf: file) else { throw CaptureError.unexpectedOutput("no JSON written") }

        return try DeviceList.parse(data).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Probes one device at a time: overlapping probes of several paired (especially wireless) devices wedge
    /// CoreDevice, after which every devicectl request, captures included, stalls until it times out.
    public static func probed(_ devices: [Device]) async -> [Device] {
        var result: [Device] = []
        for device in devices { result.append(await probe(device)) }
        return result
    }

    public static func probe(_ device: Device) async -> Device {
        var copy = device
        copy.availability = await AvailabilityProbe.probe(udid: device.udid)
        return copy
    }
}
