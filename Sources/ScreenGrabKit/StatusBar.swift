import Foundation

/// The "9:41" marketing status bar of a simulator.
/// Callers must not clear overrides they did not set: the user may have configured their own.
public enum StatusBar {

    static let cleanArguments = [
        "--time", "9:41",
        "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3",
        "--cellularMode", "active", "--cellularBars", "4", "--operatorName", "",
        // `charged` draws a green charging bolt; a full, discharging battery is the classic look.
        "--batteryState", "discharging", "--batteryLevel", "100",
    ]

    public static func hasOverrides(udid: String) async throws -> Bool {
        let output = try await Simctl.run(["status_bar", udid, "list"])
        guard output.status == 0 else { throw CaptureError.classify(output: output.text) }
        return listShowsOverrides(output.text)
    }

    public static func applyClean(udid: String) async throws {
        let output = try await Simctl.run(["status_bar", udid, "override"] + cleanArguments)
        guard output.status == 0 else { throw CaptureError.classify(output: output.text) }
    }

    public static func clear(udid: String) async throws {
        let output = try await Simctl.run(["status_bar", udid, "clear"])
        guard output.status == 0 else { throw CaptureError.classify(output: output.text) }
    }

    /// Runs `body` with the clean status bar and restores it afterwards. If the simulator already shows overrides
    /// (most likely the user's own), `body` runs as is; `applied` tells the caller which case it was.
    public static func withClean<T>(udid: String, isolation: isolated (any Actor)? = #isolation, _ body: () async throws -> T) async throws -> (result: T, applied: Bool) {
        guard try await !hasOverrides(udid: udid) else { return (try await body(), false) }
        try await applyClean(udid: udid)
        do {
            let result = try await body()
            try? await clear(udid: udid)
            return (result, true)
        } catch {
            try? await clear(udid: udid)
            throw error
        }
    }

    /// `list` prints a two-line header and then one line per override group.
    static func listShowsOverrides(_ text: String) -> Bool {
        let lines = text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let separator = lines.firstIndex(where: { $0.hasPrefix("===") }) else { return false }
        return lines[(separator + 1)...].contains { !$0.isEmpty }
    }
}
