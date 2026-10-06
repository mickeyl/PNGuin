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
        static let lastUsedUDID = "lastUsedUDID"
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

    var lastUsedUDID: String? {
        didSet { defaults.set(lastUsedUDID, forKey: Key.lastUsedUDID) }
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
        lastUsedUDID = defaults.string(forKey: Key.lastUsedUDID)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
