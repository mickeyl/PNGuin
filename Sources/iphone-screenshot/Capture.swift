import ArgumentParser
import Foundation
import ScreenGrabKit

struct Capture: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        abstract: "Capture a screenshot and print the PNG path (default command).",
        discussion: """
            Examples:
              iphone-screenshot
              iphone-screenshot --device "My iPhone" --output-dir /tmp --name home.png
            """
    )

    @Option(name: [.long, .customLong("udid"), .customLong("device-name")], help: "Device name or UDID. Defaults to $IPHONE_SCREENSHOT_DEVICE_NAME, then the only ready (unlocked, reachable) device.")
    var device: String?

    @Option(help: "Directory for the screenshot.")
    var outputDir: String?

    @Option(help: "File name (.png is appended when missing).")
    var name: String?

    func run() async throws {
        do {
            let query = device ?? ProcessInfo.processInfo.environment["IPHONE_SCREENSHOT_DEVICE_NAME"]
            var devices = try await DeviceCenter.devices()
            if query?.isEmpty ?? true { devices = await DeviceCenter.probed(devices) }
            let target = try DeviceSelector.resolve(query: query, in: devices)

            let directory = outputDir.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) } ?? OutputLocation.defaultDirectory
            let fileName = OutputLocation.normalized(name: name ?? OutputLocation.fileName())
            let destination = name == nil ? OutputLocation.uniqueURL(directory: directory, name: fileName) : directory.appendingPathComponent(fileName)

            try await Screenshotter.capture(udid: target.udid, to: destination)
            print(destination.path)
        } catch {
            throw fail(error)
        }
    }
}
