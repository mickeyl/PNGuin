import Foundation

enum Simctl {

    /// A screenshot of a simulator that shut down meanwhile hangs for a minute ("Timeout waiting for screen surfaces").
    static let timeout: Duration = .seconds(10)

    static func run(_ arguments: [String], standardOutput: URL? = nil) async throws -> Xcrun.Output {
        try await Xcrun.run("simctl", arguments, standardOutput: standardOutput, timeout: timeout)
    }
}
