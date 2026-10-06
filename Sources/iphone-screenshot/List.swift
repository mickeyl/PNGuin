import ArgumentParser
import Foundation
import ScreenGrabKit

struct List: AsyncParsableCommand {

    static let configuration = CommandConfiguration(abstract: "List paired iPhones and iPads as TSV: name, udid, availability, os.")

    @Flag(help: "Print JSON instead of TSV.")
    var json = false

    @Flag(help: "Skip the reachability/lock probe (instant, availability stays 'unknown').")
    var noProbe = false

    func run() async throws {
        do {
            let listed = try await DeviceCenter.devices()
            let devices = noProbe ? listed : await DeviceCenter.probed(listed)
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
