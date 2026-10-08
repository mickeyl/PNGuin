import Foundation
import Observation
import ScreenGrabKit
import ServiceManagement

@Observable
final class AppSettings {

    private enum Key {
        static let outputDirectory = "outputDirectory"
        static let copyToClipboard = "copyToClipboard"
        static let autoRefreshPreview = "autoRefreshPreview"
        static let lastUsed = "lastUsedByUDID"
        static let source = "source"
        static let cleanStatusBar = "cleanStatusBar"
        static let maskCorners = "maskCorners"
    }

    private let defaults = UserDefaults.standard

    var outputDirectory: URL {
        didSet { defaults.set(outputDirectory.path, forKey: Key.outputDirectory) }
    }

    var copyToClipboard: Bool {
        didSet { defaults.set(copyToClipboard, forKey: Key.copyToClipboard) }
    }

    var autoRefreshPreview: Bool {
        didSet { defaults.set(autoRefreshPreview, forKey: Key.autoRefreshPreview) }
    }

    var source: Device.Source {
        didSet { defaults.set(source.rawValue, forKey: Key.source) }
    }

    /// Simulators only: the classic 9:41 status bar, applied while a simulator is previewed or captured.
    var cleanStatusBar: Bool {
        didSet { defaults.set(cleanStatusBar, forKey: Key.cleanStatusBar) }
    }

    /// Simulators only: transparent rounded corners.
    var maskCorners: Bool {
        didSet { defaults.set(maskCorners, forKey: Key.maskCorners) }
    }

    private(set) var lastUsed: [String: Date] {
        didSet { defaults.set(lastUsed.mapValues(\.timeIntervalSince1970), forKey: Key.lastUsed) }
    }

    func markUsed(_ udid: String) {
        lastUsed[udid] = Date()
    }

    var mostRecentlyUsedUDID: String? {
        lastUsed.max { $0.value < $1.value }?.key
    }

    var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }

    init() {
        outputDirectory = defaults.string(forKey: Key.outputDirectory).map { URL(fileURLWithPath: $0, isDirectory: true) } ?? OutputLocation.defaultDirectory
        copyToClipboard = defaults.object(forKey: Key.copyToClipboard) as? Bool ?? true
        autoRefreshPreview = defaults.bool(forKey: Key.autoRefreshPreview)
        source = defaults.string(forKey: Key.source).flatMap(Device.Source.init(rawValue:)) ?? .physical
        cleanStatusBar = defaults.bool(forKey: Key.cleanStatusBar)
        maskCorners = defaults.bool(forKey: Key.maskCorners)
        lastUsed = (defaults.dictionary(forKey: Key.lastUsed) as? [String: TimeInterval] ?? [:]).mapValues(Date.init(timeIntervalSince1970:))
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
