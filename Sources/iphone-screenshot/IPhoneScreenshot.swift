import ArgumentParser
import Foundation
import ScreenGrabKit

@main
struct IPhoneScreenshot: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "iphone-screenshot",
        abstract: "Capture screenshots from attached iPhones and iPads, or from running simulators.",
        discussion: """
            Uses `xcrun devicectl` and `xcrun simctl` (Xcode 27 or later); no tunnel daemon or sudo needed.

            Exit codes: 0 ok, 1 capture failed, 3 device/simulator not found, ambiguous or not running,
            4 device locked, 64 usage, 127 Xcode missing.
            """,
        version: "0.1.3",
        subcommands: [Capture.self, List.self],
        defaultSubcommand: Capture.self
    )

    static func main() async {
        // Old callers pass --list as a flag instead of the `list` subcommand.
        let arguments = CommandLine.arguments.dropFirst().map { $0 == "--list" ? "list" : $0 }
        await main(Array(arguments))
    }
}

extension CaptureError {

    var exitCode: ExitCode {
        switch self {
            case .xcodeMissing: ExitCode(127)
            case .notFound, .noDevice, .noSimulator, .notBooted, .ambiguous: ExitCode(3)
            case .locked: ExitCode(4)
            case .developerDiskImage, .unexpectedOutput, .failed: ExitCode(1)
        }
    }
}

func fail(_ error: Error) -> ExitCode {
    let message = (error as? LocalizedError)?.errorDescription ?? "\(error)"
    FileHandle.standardError.write(Data("iphone-screenshot: \(message)\n".utf8))
    return (error as? CaptureError)?.exitCode ?? ExitCode(1)
}
