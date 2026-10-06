import SwiftUI
import ScreenGrabKit

struct DeviceMenuView: View {

    let model: AppModel
    @State private var showsSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionGap) {
            devices
            if model.selectedDevice != nil {
                PreviewView(state: model.preview)
            }
            if let message = model.errorMessage {
                Text(message)
                    .font(.statusNote)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let capture = model.lastCapture {
                LastCaptureView(record: capture, model: model)
            }
            Divider()
            footer
            if showsSettings { SettingsView(settings: model.settings) }
        }
        .padding(Metrics.inset)
        .frame(width: Metrics.popoverWidth)
        .background(WindowVisibilityObserver { visible in
            if visible { model.menuDidOpen() } else { model.menuDidClose() }
        })
    }

    @ViewBuilder
    private var devices: some View {
        if model.devices.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(model.hasScanned ? R.L.DeviceMenuView_EMPTY_TITLE : R.L.DeviceMenuView_SCANNING)
                    .font(.rowTitle)
                if model.hasScanned {
                    Text(R.L.DeviceMenuView_EMPTY_HINT)
                        .font(.statusNote)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            VStack(spacing: Metrics.rowGap / 2) {
                ForEach(model.devices) { device in
                    DeviceRow(
                        device: device,
                        isSelected: device.udid == model.selectedUDID,
                        isCapturing: model.capturing.contains(device.udid),
                        select: { model.select(device) },
                        capture: { Task { await model.capture(device) } }
                    )
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button(R.L.DeviceMenuView_SETTINGS, systemImage: "gearshape") { showsSettings.toggle() }
            Spacer()
            Button(R.L.DeviceMenuView_QUIT) { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .buttonStyle(.plain)
        .font(.fieldLabel)
        .foregroundStyle(.secondary)
    }
}
