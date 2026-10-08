import CoreGraphics
import Foundation
import Testing
@testable import PNGuinKit

private let simulatorFixture = """
{"devicetypes":[
  {"identifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro","productFamily":"iPhone","name":"iPhone 18 Pro"},
  {"identifier":"com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5","productFamily":"iPad","name":"iPad Pro 11-inch (M5)"},
  {"identifier":"com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm","productFamily":"Apple Watch","name":"Apple Watch Series 11 (46mm)"}
 ],
 "runtimes":[
  {"identifier":"com.apple.CoreSimulator.SimRuntime.iOS-27-0","platform":"iOS","version":"27.0"},
  {"identifier":"com.apple.CoreSimulator.SimRuntime.watchOS-27-0","platform":"watchOS","version":"27.0"}
 ],
 "devices":{
  "com.apple.CoreSimulator.SimRuntime.iOS-27-0":[
   {"udid":"S-PHONE","name":"iPhone 18 Pro","state":"Booted","isAvailable":true,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"},
   {"udid":"S-PAD","name":"iPad Pro 11-inch (M5)","state":"Booted","isAvailable":true,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPad-Pro-11-inch-M5"},
   {"udid":"S-OFF","name":"iPhone 18 Pro","state":"Shutdown","isAvailable":true,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"},
   {"udid":"S-GONE","name":"iPhone 18 Pro","state":"Booted","isAvailable":false,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro"}
  ],
  "com.apple.CoreSimulator.SimRuntime.iOS-26-4":[
   {"udid":"S-OLD","name":"iPhone 15","state":"Booted","isAvailable":true,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.iPhone-15"}
  ],
  "com.apple.CoreSimulator.SimRuntime.watchOS-27-0":[
   {"udid":"S-WATCH","name":"Apple Watch Series 11 (46mm)","state":"Booted","isAvailable":true,"deviceTypeIdentifier":"com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Series-11-46mm"}
  ]
 }}
"""

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

@Suite struct PreviewCacheTests {

    @Test func exportedCopyUsesScreenshotName() throws {
        let udid = "test-\(UUID().uuidString)"
        let source = PreviewCache.url(for: udid)
        try FileManager.default.createDirectory(at: PreviewCache.directory, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: source.path, contents: Data([1, 2, 3]))
        defer { try? FileManager.default.removeItem(at: source) }

        let exported = try PreviewCache.exportedCopy(udid: udid)
        defer { try? FileManager.default.removeItem(at: exported) }

        #expect(exported.lastPathComponent.hasPrefix("iphone-screenshot-"))
        #expect(try Data(contentsOf: exported) == Data([1, 2, 3]))
        #expect(FileManager.default.fileExists(atPath: source.path))
    }
}

@Suite struct ImageScalerTests {

    @Test func scalesToExactPixelSize() async throws {
        let context = try #require(CGContext(data: nil, width: 1206, height: 2622, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 1206, height: 2622))
        let source = try #require(context.makeImage())

        let scaled = try #require(await ImageScaler.scaled(source, width: 147, height: 320))
        #expect(scaled.width == 147)
        #expect(scaled.height == 320)
    }

    @Test func rejectsEmptyTarget() async throws {
        let context = try #require(CGContext(data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let source = try #require(context.makeImage())
        #expect(await ImageScaler.scaled(source, width: 0, height: 10) == nil)
    }
}

@Suite struct SimulatorListTests {

    private func parsed() throws -> [String: Device] {
        let devices = try SimulatorList.parse(Data(simulatorFixture.utf8))
        return Dictionary(uniqueKeysWithValues: devices.map { ($0.udid, $0) })
    }

    @Test func keepsBootedPhonesAndPads() throws {
        let devices = try parsed()
        #expect(Set(devices.keys) == ["S-PHONE", "S-PAD", "S-OLD"])
        #expect(devices["S-PHONE"]?.kind == .iPhone)
        #expect(devices["S-PAD"]?.kind == .iPad)
        #expect(devices.values.allSatisfy { $0.source == .simulator && $0.isReady })
    }

    @Test func versionFallsBackToRuntimeIdentifier() throws {
        #expect(try parsed()["S-PHONE"]?.osVersion == "27.0")
        #expect(try parsed()["S-OLD"]?.osVersion == "26.4")
    }

    @Test func rejectsUnknownSchema() {
        #expect(throws: CaptureError.self) { try SimulatorList.parse(Data(#"{"simulators":[]}"#.utf8)) }
    }
}

@Suite struct StatusBarTests {

    @Test func headerOnlyMeansNoOverrides() {
        #expect(!StatusBar.listShowsOverrides("Current Status Bar Overrides:\n=============================\n"))
    }

    @Test func detectsOverrides() {
        #expect(StatusBar.listShowsOverrides("Current Status Bar Overrides:\n=============================\nTime: 09:41\n"))
    }

    @Test func shutdownSimulatorIsNotBooted() {
        #expect(CaptureError.classify(output: "Unable to lookup in current state: Shutdown") == .notBooted)
        #expect(CaptureError.classify(output: "Timeout waiting for screen surfaces") == .notBooted)
    }
}
