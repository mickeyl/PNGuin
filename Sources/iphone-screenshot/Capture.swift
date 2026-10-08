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
              iphone-screenshot --simulator --clean-status-bar --mask-corners
            """
    )

    @Option(name: [.long, .customLong("udid"), .customLong("device-name")], help: "Device name or UDID. Defaults to $IPHONE_SCREENSHOT_DEVICE_NAME, then the only ready (unlocked, reachable) device.")
    var device: String?

    @Option(help: "Directory for the screenshot.")
    var outputDir: String?

    @Option(help: "File name (.png is appended when missing).")
    var name: String?

    @Flag(help: "Capture a running iPhone/iPad simulator instead of a physical device (default: the only one running).")
    var simulator = false

    @Flag(help: "Simulator only: show the classic 9:41 status bar while capturing. Overrides you set yourself are left alone.")
    var cleanStatusBar = false

    @Flag(help: "Simulator only: give the screenshot transparent rounded corners.")
    var maskCorners = false

    func validate() throws {
        guard simulator || !(cleanStatusBar || maskCorners) else {
            throw ValidationError("--clean-status-bar and --mask-corners require --simulator.")
        }
    }

    func run() async throws {
        do {
            let target = try await resolveTarget()

            let directory = outputDir.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath, isDirectory: true) } ?? OutputLocation.defaultDirectory
            let fileName = OutputLocation.normalized(name: name ?? OutputLocation.fileName())
            let destination = name == nil ? OutputLocation.uniqueURL(directory: directory, name: fileName) : directory.appendingPathComponent(fileName)

            try await capture(target, to: destination)
            print(destination.path)
        } catch {
            throw fail(error)
        }
    }

    private func resolveTarget() async throws -> Device {
        guard simulator else {
            let query = device ?? ProcessInfo.processInfo.environment["IPHONE_SCREENSHOT_DEVICE_NAME"]
            var devices = try await DeviceCenter.devices()
            if query?.isEmpty ?? true { devices = await DeviceCenter.probed(devices) }
            return try DeviceSelector.resolve(query: query, in: devices)
        }
        let simulators = try await SimulatorCenter.simulators()
        guard !simulators.isEmpty else { throw CaptureError.noSimulator }
        return try DeviceSelector.resolve(query: device, in: simulators)
    }

    private func capture(_ target: Device, to destination: URL) async throws {
        guard cleanStatusBar else {
            try await Screenshotter.capture(target, to: destination, maskCorners: maskCorners)
            return
        }
        let (_, applied) = try await StatusBar.withClean(udid: target.udid) {
            try await Screenshotter.capture(target, to: destination, maskCorners: maskCorners)
        }
        if !applied {
            FileHandle.standardError.write(Data("iphone-screenshot: the status bar already has overrides; left as is.\n".utf8))
        }
    }
}
