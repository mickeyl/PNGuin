import Foundation
import Testing
@testable import ScreenGrabKit

private let fixture = """
{"result":{"devices":[
 {"deviceProperties":{"name":"Alpha","osVersionNumber":"27.0.1"},
  "hardwareProperties":{"udid":"U-ALPHA","deviceType":"iPhone","reality":"physical"},
  "connectionProperties":{"tunnelState":"connected"}},
 {"deviceProperties":{"name":"Beta","osVersionNumber":"26.6"},
  "hardwareProperties":{"udid":"U-BETA","deviceType":"iPad","reality":"physical"},
  "connectionProperties":{"tunnelState":"disconnected"}},
 {"deviceProperties":{"name":"Sim"},
  "hardwareProperties":{"udid":"U-SIM","deviceType":"iPhone","reality":"simulated"},
  "connectionProperties":{"tunnelState":"disconnected"}},
 {"deviceProperties":{"name":"Watch"},
  "hardwareProperties":{"udid":"U-W","deviceType":"appleWatch","reality":"physical"},
  "connectionProperties":{"tunnelState":"connected"}}
]}}
"""

@Suite struct DeviceListTests {

    @Test func keepsOnlyPhysicalPhonesAndPads() throws {
        let devices = try DeviceList.parse(Data(fixture.utf8))
        #expect(devices.map(\.name) == ["Alpha", "Beta"])
        #expect(devices.allSatisfy { $0.availability == .unknown })
        #expect(devices[0].osVersion == "27.0.1")
    }

    @Test func rejectsUnknownSchema() {
        #expect(throws: CaptureError.self) { try DeviceList.parse(Data("{}".utf8)) }
    }
}

@Suite struct DeviceSelectorTests {

    let devices = [
        Device(name: "Alpha", udid: "U-A", kind: .iPhone, osVersion: nil, availability: .ready),
        Device(name: "Beta", udid: "U-B", kind: .iPhone, osVersion: nil, availability: .ready),
        Device(name: "Gamma", udid: "U-G", kind: .iPad, osVersion: nil, availability: .unreachable),
        Device(name: "Delta", udid: "U-D", kind: .iPhone, osVersion: nil, availability: .locked),
    ]

    @Test func matchesNameCaseInsensitively() throws {
        #expect(try DeviceSelector.resolve(query: "alpha", in: devices).udid == "U-A")
    }

    @Test func queryIgnoresAvailability() throws {
        #expect(try DeviceSelector.resolve(query: "U-G", in: devices).name == "Gamma")
    }

    @Test func unknownQueryIsNotFound() {
        #expect(throws: CaptureError.notFound(query: "x")) { try DeviceSelector.resolve(query: "x", in: devices) }
    }

    @Test func twoReadyWithoutQueryIsAmbiguous() {
        #expect(throws: CaptureError.ambiguous(candidates: ["Alpha", "Beta"])) { try DeviceSelector.resolve(query: nil, in: devices) }
    }

    @Test func singleReadyIsChosen() throws {
        #expect(try DeviceSelector.resolve(query: nil, in: [devices[0], devices[2], devices[3]]).name == "Alpha")
    }

    @Test func onlyLockedDeviceReportsLocked() {
        #expect(throws: CaptureError.locked) { try DeviceSelector.resolve(query: nil, in: [devices[2], devices[3]]) }
    }

    @Test func noneReady() {
        #expect(throws: CaptureError.noDevice) { try DeviceSelector.resolve(query: nil, in: [devices[2]]) }
    }
}

@Suite struct AvailabilityProbeTests {

    @Test func unlockedIsReady() {
        let json = Data(#"{"result":{"passcodeRequired":false}}"#.utf8)
        #expect(AvailabilityProbe.classify(status: 0, output: "", json: json) == .ready)
    }

    @Test func passcodeRequiredIsLocked() {
        let json = Data(#"{"result":{"passcodeRequired":true}}"#.utf8)
        #expect(AvailabilityProbe.classify(status: 0, output: "", json: json) == .locked)
    }

    @Test func lockedErrorIsLocked() {
        #expect(AvailabilityProbe.classify(status: 1, output: "ERROR: still locked (error 10003)", json: nil) == .locked)
    }

    @Test func otherFailureIsUnreachable() {
        #expect(AvailabilityProbe.classify(status: 1, output: "ERROR: timed out", json: nil) == .unreachable)
    }
}

@Suite struct ErrorClassificationTests {

    @Test func locked() {
        #expect(CaptureError.classify(output: "ERROR: x (com.apple.dt.CoreDeviceError error 10003 (0x2713))") == .locked)
    }

    @Test func diskImage() {
        #expect(CaptureError.classify(output: "ERROR: The developer disk image could not be mounted (error 12040)") == .developerDiskImage)
    }

    @Test func genericUsesErrorLine() {
        #expect(CaptureError.classify(output: "noise\nERROR: boom\n  detail") == .failed("boom"))
    }
}

@Suite struct OutputLocationTests {

    @Test func appendsPNGExtension() {
        #expect(OutputLocation.normalized(name: "a") == "a.png")
        #expect(OutputLocation.normalized(name: "a.PNG") == "a.PNG")
    }

    @Test func uniqueURLAvoidsOverwrite() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        FileManager.default.createFile(atPath: dir.appendingPathComponent("a.png").path, contents: Data([1]))
        #expect(OutputLocation.uniqueURL(directory: dir, name: "a.png").lastPathComponent == "a-1.png")
    }
}
