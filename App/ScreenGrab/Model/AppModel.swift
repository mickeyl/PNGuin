import AppKit

import CornucopiaCore
import Observation
import ScreenGrabKit

private let logger = Cornucopia.Core.Logger()

@Observable
final class AppModel {

    enum PreviewState {
        case none
        case loading
        case image(NSImage)
        case unavailable(Device.Availability)
    }

    private static let deviceRefreshInterval: Duration = .seconds(5)
    private static let previewPollInterval: Duration = .milliseconds(300)

    let settings = AppSettings()

    private(set) var devices: [Device] = []
    private(set) var hasScanned = false
    private(set) var capturing: Set<String> = []
    private(set) var preview: PreviewState = .none
    private(set) var lastCapture: CaptureRecord?
    var errorMessage: String?

    private(set) var selectedUDID: String? {
        didSet {
            guard selectedUDID != oldValue else { return }
            showCachedPreview()
        }
    }

    // Until the user picks a row, the selection follows the best device, which is only known once probing has finished.
    @ObservationIgnored private var selectionIsManual = false

    func select(_ device: Device) {
        selectionIsManual = true
        selectedUDID = device.udid
    }

    @ObservationIgnored private var monitoring: Task<Void, Never>?
    @ObservationIgnored private var previewLoadedFor: String?

    // MARK: Menu visibility

    func menuDidOpen() {
        guard monitoring == nil else { return }
        logger.debug("menu opened, start monitoring")
        previewLoadedFor = nil
        monitoring = Task { [weak self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self?.deviceLoop() }
                group.addTask { await self?.previewLoop() }
            }
        }
    }

    func menuDidClose() {
        logger.debug("menu closed, stop monitoring")
        monitoring?.cancel()
        monitoring = nil
    }

    // MARK: Device discovery

    private func deviceLoop() async {
        while !Task.isCancelled {
            await refreshDevices()
            try? await Task.sleep(for: Self.deviceRefreshInterval)
        }
    }

    private func refreshDevices() async {
        do {
            let listed = try await DeviceCenter.devices()
            // Keep the last known state so rows don't flash back to "Checking…" while the sequential pass runs.
            let known = Dictionary(devices.map { ($0.udid, $0.availability) }, uniquingKeysWith: { first, _ in first })
            apply(listed.map { device in
                var device = device
                device.availability = known[device.udid] ?? .unknown
                return device
            })
            // Probes must not overlap (see `DeviceCenter.probed`), so publish each result as it arrives, selected device first.
            let order = devices.filter { $0.udid == selectedUDID } + devices.filter { $0.udid != selectedUDID }
            for device in order {
                let availability = await DeviceCenter.probe(device).availability
                guard !Task.isCancelled else { return }
                update(device.udid, to: availability)
            }
        } catch {
            logger.error("device refresh failed: \(error)")
            hasScanned = true
        }
    }

    /// Most recently used first, then by name. Availability deliberately plays no part, so rows don't jump when a device locks.
    private func sorted(_ devices: [Device]) -> [Device] {
        devices.sorted {
            (settings.lastUsed[$1.udid] ?? .distantPast, $0.name.lowercased()) < (settings.lastUsed[$0.udid] ?? .distantPast, $1.name.lowercased())
        }
    }

    private func apply(_ listed: [Device]) {
        let newDevices = sorted(listed)
        devices = newDevices
        hasScanned = true
        let selectionStillValid = newDevices.contains { $0.udid == selectedUDID }
        guard !selectionIsManual || !selectionStillValid else { return }
        selectionIsManual = false
        // The best device is the most recently used ready one. A more recent device still being probed might beat it,
        // so only commit once nothing ahead of it is pending; otherwise the selection hops while probes come in.
        let candidates = newDevices.prefix { !$0.isReady }
        let best = newDevices.first(where: \.isReady) ?? newDevices.first
        let bestIsSettled = !candidates.contains { $0.availability == .unknown }
        guard bestIsSettled || !selectionStillValid else { return }
        selectedUDID = best?.udid
    }

    private func update(_ udid: String, to availability: Device.Availability) {
        guard let index = devices.firstIndex(where: { $0.udid == udid }), devices[index].availability != availability else { return }
        logger.debug("\(devices[index].name): \(devices[index].availability.rawValue) -> \(availability.rawValue)")
        var updated = devices
        updated[index].availability = availability
        apply(updated)
    }

    var selectedDevice: Device? { devices.first { $0.udid == selectedUDID } }

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
        guard let device = selectedDevice else { return }
        guard device.isReady else {
            if device.availability != .unknown { preview = .unavailable(device.availability) }
            return
        }
        guard settings.autoRefreshPreview || previewLoadedFor != device.udid else { return }

        if case .image = preview {} else { preview = .loading }
        previewLoadedFor = device.udid
        do {
            let url = try await PreviewCache.capture(udid: device.udid)
            guard !Task.isCancelled, selectedUDID == device.udid, let image = NSImage(contentsOf: url) else { return }
            preview = .image(image)
        } catch {
            logger.warning("preview failed for \(device.name): \(error)")
            guard selectedUDID == device.udid else { return }
            if case .image = preview {} else { preview = .unavailable(.unreachable) }
        }
    }

    // MARK: Capture

    func capture(_ device: Device) async {
        guard !capturing.contains(device.udid) else { return }
        capturing.insert(device.udid)
        defer { capturing.remove(device.udid) }
        errorMessage = nil

        let destination = OutputLocation.uniqueURL(directory: settings.outputDirectory, name: OutputLocation.fileName())
        do {
            try await Screenshotter.capture(udid: device.udid, to: destination)
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
