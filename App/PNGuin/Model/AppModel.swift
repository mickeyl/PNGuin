import AppKit

import CornucopiaCore
import Observation
import PNGuinKit

private let logger = Cornucopia.Core.Logger()

@Observable
final class AppModel {

    enum PreviewState {
        case none
        case loading
        case image(NSImage)
        case unavailable(Device.Availability)
    }

    /// What the current preview was captured with; a change (another device, a toggled option) calls for a new capture.
    private struct PreviewKey: Equatable {
        let udid: String
        let maskCorners: Bool
        let cleanStatusBar: Bool
    }

    private static let simulatorRefreshInterval: Duration = .seconds(2)
    private static let previewPollInterval: Duration = .milliseconds(300)

    let settings = AppSettings()

    private(set) var source: Device.Source
    private(set) var lists: [Device.Source: [Device]] = [:]
    private(set) var scanned: Set<Device.Source> = []
    private(set) var capturing: Set<String> = []
    private(set) var preview: PreviewState = .none
    private(set) var lastCapture: CaptureRecord?
    var errorMessage: String?

    private var selections: [Device.Source: String] = [:]

    // Until the user picks a row, the selection follows the best device, which is only known once probing has finished.
    @ObservationIgnored private var manualSelections: Set<Device.Source> = []
    @ObservationIgnored private var monitoring: Task<Void, Never>?
    @ObservationIgnored private var previewLoadedFor: PreviewKey?
    @ObservationIgnored private let statusBar = StatusBarKeeper()

    init() {
        source = settings.source
    }

    var devices: [Device] { lists[source] ?? [] }
    var hasScanned: Bool { scanned.contains(source) }
    var selectedUDID: String? { selections[source] }
    var selectedDevice: Device? { devices.first { $0.udid == selectedUDID } }

    /// Nil until the source has been scanned at least once.
    func count(of source: Device.Source) -> Int? {
        scanned.contains(source) ? lists[source]?.count ?? 0 : nil
    }

    func show(_ newSource: Device.Source) {
        guard newSource != source else { return }
        source = newSource
        settings.source = newSource
        errorMessage = nil
        showCachedPreview()
        guard monitoring != nil else { return }
        stopMonitoring()
        startMonitoring()
    }

    func select(_ device: Device) {
        manualSelections.insert(device.source)
        setSelection(device.udid, for: device.source)
    }

    private func setSelection(_ udid: String?, for source: Device.Source) {
        guard selections[source] != udid else { return }
        selections[source] = udid
        if source == self.source { showCachedPreview() }
    }

    // MARK: Menu visibility

    func menuDidOpen() {
        guard monitoring == nil else { return }
        logger.debug("menu opened, start monitoring")
        startMonitoring()
    }

    func menuDidClose() {
        logger.debug("menu closed, stop monitoring")
        stopMonitoring()
        Task { await statusBar.hold(nil) }
    }

    private func startMonitoring() {
        previewLoadedFor = nil
        let source = source
        monitoring = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                // Simulators are cheap to list, so they are always polled to keep the segment count current.
                group.addTask { await self?.simulatorLoop() }
                if source == .physical { group.addTask { await self?.deviceLoop() } }
                group.addTask { await self?.previewLoop() }
            }
        }
    }

    private func stopMonitoring() {
        monitoring?.cancel()
        monitoring = nil
    }

    // MARK: Discovery

    private func deviceLoop() async {
        while !Task.isCancelled {
            do {
                try await DeviceMonitor.refresh(current: { lists[.physical] ?? [] }, selected: selections[.physical]) { apply($0, for: .physical) }
            } catch {
                logger.error("device refresh failed: \(error)")
                scanned.insert(.physical)
            }
            try? await Task.sleep(for: DeviceMonitor.interval)
        }
    }

    private func simulatorLoop() async {
        while !Task.isCancelled {
            do {
                apply(try await SimulatorCenter.simulators(), for: .simulator)
            } catch {
                logger.error("simulator refresh failed: \(error)")
                scanned.insert(.simulator)
            }
            try? await Task.sleep(for: Self.simulatorRefreshInterval)
        }
    }

    /// Most recently used first, then by name. Availability deliberately plays no part, so rows don't jump when a device locks.
    private func sorted(_ devices: [Device]) -> [Device] {
        devices.sorted {
            (settings.lastUsed[$1.udid] ?? .distantPast, $0.name.lowercased()) < (settings.lastUsed[$0.udid] ?? .distantPast, $1.name.lowercased())
        }
    }

    private func apply(_ listed: [Device], for source: Device.Source) {
        let newDevices = sorted(listed)
        guard newDevices != lists[source] || !scanned.contains(source) else { return }
        lists[source] = newDevices
        scanned.insert(source)

        let selectionStillValid = newDevices.contains { $0.udid == selections[source] }
        guard !manualSelections.contains(source) || !selectionStillValid else { return }
        manualSelections.remove(source)
        // The best device is the most recently used ready one. A more recent device still being probed might beat it,
        // so only commit once nothing ahead of it is pending; otherwise the selection hops while probes come in.
        let candidates = newDevices.prefix { !$0.isReady }
        let best = newDevices.first(where: \.isReady) ?? newDevices.first
        let bestIsSettled = !candidates.contains { $0.availability == .unknown }
        guard bestIsSettled || !selectionStillValid else { return }
        setSelection(best?.udid, for: source)
    }

    // MARK: Preview

    private func showCachedPreview() {
        previewLoadedFor = nil
        guard let udid = selectedUDID, let image = NSImage(contentsOf: PreviewCache.url(for: udid)) else {
            preview = .none
            return
        }
        preview = .image(image)
    }

    func copyPreview() {
        guard case .image(let image) = preview else { return }
        copy(image)
        markSelectedUsed()
    }

    /// Hands out a file (not just image data), so Finder, Mail, chats etc. all accept the drop.
    func previewDragItem() -> NSItemProvider {
        guard
            let udid = selectedUDID,
            let url = try? PreviewCache.exportedCopy(udid: udid),
            let provider = NSItemProvider(contentsOf: url)
        else { return NSItemProvider() }
        markSelectedUsed()
        return provider
    }

    /// Taking a preview out by copy or drag counts as using the device, just like a saved screenshot.
    private func markSelectedUsed() {
        guard let udid = selectedUDID else { return }
        settings.markUsed(udid)
    }

    private func previewLoop() async {
        while !Task.isCancelled {
            await refreshPreviewIfNeeded()
            try? await Task.sleep(for: Self.previewPollInterval)
        }
    }

    private func refreshPreviewIfNeeded() async {
        // Copy and drag hand out the preview, so it is captured exactly like a saved screenshot would be.
        await statusBar.hold(source == .simulator && settings.cleanStatusBar ? selectedUDID : nil)
        guard !Task.isCancelled, let device = selectedDevice else { return }
        guard device.isReady else {
            if device.availability != .unknown { preview = .unavailable(device.availability) }
            return
        }
        let key = PreviewKey(udid: device.udid, maskCorners: maskCorners(for: device), cleanStatusBar: statusBar.held == device.udid)
        guard settings.autoRefreshPreview || previewLoadedFor != key else { return }

        if case .image = preview {} else { preview = .loading }
        previewLoadedFor = key
        do {
            let url = try await PreviewCache.capture(device, maskCorners: key.maskCorners)
            guard !Task.isCancelled, selectedUDID == device.udid, let image = NSImage(contentsOf: url) else { return }
            preview = .image(image)
        } catch {
            logger.warning("preview failed for \(device.name): \(error)")
            guard selectedUDID == device.udid else { return }
            if case .image = preview {} else { preview = .unavailable(.unreachable) }
        }
    }

    private func maskCorners(for device: Device) -> Bool {
        device.source == .simulator && settings.maskCorners
    }

    // MARK: Capture

    func capture(_ device: Device) async {
        guard !capturing.contains(device.udid) else { return }
        capturing.insert(device.udid)
        defer { capturing.remove(device.udid) }
        errorMessage = nil

        let destination = OutputLocation.uniqueURL(directory: settings.outputDirectory, name: OutputLocation.fileName())
        let maskCorners = maskCorners(for: device)
        do {
            // The previewed simulator already carries the clean status bar; any other one gets it just for this capture.
            if device.source == .simulator, settings.cleanStatusBar, statusBar.held != device.udid {
                _ = try await StatusBar.withClean(udid: device.udid) {
                    try await Screenshotter.capture(device, to: destination, maskCorners: maskCorners)
                }
            } else {
                try await Screenshotter.capture(device, to: destination, maskCorners: maskCorners)
            }
            guard let image = NSImage(contentsOf: destination) else { return }
            settings.markUsed(device.udid)
            lastCapture = CaptureRecord(url: destination, image: image, deviceName: device.name)
            if settings.copyToClipboard { copy(image) }
            logger.info("saved \(destination.path)")
        } catch CaptureError.locked {
            errorMessage = R.L.AppModel_ERROR_LOCKED
        } catch {
            logger.error("capture failed: \(error)")
            errorMessage = R.L.AppModel_ERROR_FAILED((error as? LocalizedError)?.errorDescription ?? "\(error)")
        }
    }

    func copy(_ image: NSImage) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
    }
}
