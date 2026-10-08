import SwiftUI
import ScreenGrabKit

struct DeviceMenuView: View {

    let model: AppModel
    @State private var showsSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.sectionGap) {
            header
            devices
            if model.selectedDevice != nil {
                PreviewView(state: model.preview, copy: model.copyPreview, dragItem: model.previewDragItem)
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

    private var header: some View {
        HStack(spacing: Metrics.rowGap) {
            SourcePicker(model: model)
                .fixedSize()
            Spacer(minLength: Metrics.rowGap)
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: Metrics.headerIconSize, height: Metrics.headerIconSize)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var devices: some View {
        if model.devices.isEmpty {
            EmptyStateView(source: model.source, hasScanned: model.hasScanned)
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
