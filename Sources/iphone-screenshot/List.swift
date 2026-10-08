import ArgumentParser
import Foundation
import PNGuinKit

struct List: AsyncParsableCommand {

    static let configuration = CommandConfiguration(abstract: "List paired iPhones and iPads (or running simulators) as TSV: name, udid, availability, os.")

    @Flag(help: "Print JSON instead of TSV.")
    var json = false

    @Flag(help: "Skip the reachability/lock probe (instant, availability stays 'unknown').")
    var noProbe = false

    @Flag(help: "List running iPhone/iPad simulators instead (always 'ready').")
    var simulators = false

    func run() async throws {
        do {
            let devices = if simulators {
                try await SimulatorCenter.simulators()
            } else {
                noProbe ? try await DeviceCenter.devices() : await DeviceCenter.probed(try await DeviceCenter.devices())
            }
            if json {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                print(String(decoding: try encoder.encode(devices), as: UTF8.self))
            } else {
                for device in devices {
                    print([device.name, device.udid, device.availability.rawValue, device.osVersion ?? "-"].joined(separator: "\t"))
                }
            }
        } catch {
            throw fail(error)
        }
    }
}
