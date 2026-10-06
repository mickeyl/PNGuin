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
        lastUsed = (defaults.dictionary(forKey: Key.lastUsed) as? [String: TimeInterval] ?? [:]).mapValues(Date.init(timeIntervalSince1970:))
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
