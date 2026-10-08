import Foundation

enum Devicectl {

    static func run(_ arguments: [String]) async throws -> Xcrun.Output {
        try await Xcrun.run("devicectl", arguments)
    }
}
