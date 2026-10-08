import Foundation

public enum SimulatorCenter {

    /// Booted iPhone and iPad simulators, sorted by name.
    public static func simulators() async throws -> [Device] {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("pnguin-simulators-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }

        let output = try await Simctl.run(["list", "-j"], standardOutput: file)
        guard output.status == 0 else { throw CaptureError.classify(output: output.text) }
        guard let data = try? Data(contentsOf: file) else { throw CaptureError.unexpectedOutput("no JSON written") }

        return try SimulatorList.parse(data).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
