import SwiftUI
import PNGuinKit

struct DeviceRow: View {

    let device: Device
    let isSelected: Bool
    let isCapturing: Bool
    let select: () -> Void
    let capture: () -> Void

    var body: some View {
        HStack(spacing: Metrics.rowGap) {
            Image(systemName: device.symbolName)
                .font(.title3)
                .foregroundStyle(device.availability.tint)
                .frame(width: Metrics.iconColumnWidth, alignment: .trailing)

            VStack(alignment: .leading, spacing: 1) {
                Text(device.name).font(.rowTitle).lineLimit(1)
                Text(detail).font(.rowDetail).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: Metrics.rowGap)

            if isCapturing {
                ProgressView().controlSize(.small)
            } else {
                Button(action: capture) {
                    Image(systemName: "camera.viewfinder").font(.title3)
                }
                .buttonStyle(.borderless)
                .disabled(!device.isReady)
                .help(R.L.DeviceRow_CAPTURE_HELP)
                .accessibilityLabel(R.L.DeviceRow_CAPTURE_HELP)
            }
        }
        .padding(.horizontal, Metrics.rowGap)
        .frame(height: Metrics.rowHeight)
        .background(isSelected ? Color.accentColor.opacity(0.15) : .clear, in: .rect(cornerRadius: 8))
        .contentShape(.rect)
        .onTapGesture(perform: select)
    }

    private var detail: String {
        [device.osVersion, device.availability.title].compactMap { $0 }.joined(separator: " · ")
    }
}
