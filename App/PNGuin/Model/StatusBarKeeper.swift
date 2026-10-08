import AppKit

import CornucopiaCore
import PNGuinKit

private let logger = Cornucopia.Core.Logger()

/// Keeps the clean status bar on the simulator being previewed, so copied or dragged previews match saved captures.
/// It is applied once per simulator rather than per frame, which would make the Simulator window flicker, and only
/// what it applied itself is ever cleared. Those UDIDs are persisted, so a crash doesn't leave a fake status bar behind.
final class StatusBarKeeper {

    private static let ownedKey = "statusBarOverridesInEffect"

    private(set) var held: String?
    private var termination: NSObjectProtocol?

    private var owned: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.ownedKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Self.ownedKey) }
    }

    init() {
        let leftovers = owned
        owned = []
        Task {
            for udid in leftovers { try? await StatusBar.clear(udid: udid) }
        }
        termination = NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.releaseBeforeExit() }
        }
    }

    /// Moves the clean status bar to `udid`; nil releases it.
    func hold(_ udid: String?) async {
        guard udid != held else { return }
        let previous = held
        held = udid
        if let previous, owned.contains(previous) {
            owned.remove(previous)
            try? await StatusBar.clear(udid: previous)
        }
        guard let udid else { return }

        do {
            guard try await !StatusBar.hasOverrides(udid: udid), held == udid else { return }
            try await StatusBar.applyClean(udid: udid)
            owned.insert(udid)
            // Released while the override was being applied: undo it right away instead of leaking it.
            guard held != udid else { return }
            owned.remove(udid)
            try? await StatusBar.clear(udid: udid)
        } catch {
            logger.warning("status bar override failed for \(udid): \(error)")
        }
    }

    /// The run loop is about to stop, so this cannot await; a blocking simctl call per simulator is fine here.
    private func releaseBeforeExit() {
        for udid in owned {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
            process.arguments = ["simctl", "status_bar", udid, "clear"]
            try? process.run()
            process.waitUntilExit()
        }
        owned = []
    }
}
