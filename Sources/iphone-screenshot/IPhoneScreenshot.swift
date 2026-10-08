import ArgumentParser
import Foundation
import ScreenGrabKit

@main
struct IPhoneScreenshot: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "iphone-screenshot",
        abstract: "Capture screenshots from attached iPhones and iPads.",
        discussion: """
            Uses `xcrun devicectl` (Xcode 27 or later); no tunnel daemon or sudo needed.

            Exit codes: 0 ok, 1 capture failed, 2 usage, 3 device not found or ambiguous,
            4 device locked, 127 devicectl missing.
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
            case .devicectlMissing: ExitCode(127)
            case .notFound, .noDevice, .ambiguous: ExitCode(3)
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
