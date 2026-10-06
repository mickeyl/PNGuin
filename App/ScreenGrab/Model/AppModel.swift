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
            // Publish the unprobed list first so the menu fills immediately instead of waiting for the slowest probe.
            if devices.isEmpty { apply(listed) }
            let probed = await DeviceCenter.probed(listed)
            guard !Task.isCancelled else { return }
            apply(probed)
        } catch {
            logger.error("device refresh failed: \(error)")
            hasScanned = true
        }
    }

    /// Ready devices first, then most recently used, then by name (the order devices arrive in).
    private func sorted(_ devices: [Device]) -> [Device] {
        func rank(_ device: Device) -> Int {
            switch device.availability {
                case .ready: 0
                case .unknown, .locked: 1
                case .unreachable: 2
            }
        }
        return devices.sorted {
            (rank($0), settings.lastUsed[$1.udid] ?? .distantPast, $0.name.lowercased()) < (rank($1), settings.lastUsed[$0.udid] ?? .distantPast, $1.name.lowercased())
        }
    }

    private func apply(_ listed: [Device]) {
        let newDevices = sorted(listed)
        devices = newDevices
        hasScanned = true
        let selectionStillValid = newDevices.contains { $0.udid == selectedUDID }
        guard !selectionIsManual || !selectionStillValid else { return }
        selectionIsManual = selectionIsManual && selectionStillValid
        selectedUDID = newDevices.first?.udid
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
