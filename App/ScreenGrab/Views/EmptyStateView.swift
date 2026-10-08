import AppKit
import SwiftUI
import ScreenGrabKit

struct EmptyStateView: View {

    let source: Device.Source
    let hasScanned: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.rowTitle)
            if hasScanned {
                Text(hint)
                    .font(.statusNote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if source == .simulator {
                    Button(R.L.EmptyStateView_OPEN_SIMULATOR, action: openSimulator)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var title: String {
        switch (source, hasScanned) {
            case (_, false): R.L.DeviceMenuView_SCANNING
            case (.physical, true): R.L.DeviceMenuView_EMPTY_TITLE
            case (.simulator, true): R.L.EmptyStateView_NO_SIMULATORS_TITLE
        }
    }

    private var hint: String {
        switch source {
            case .physical: R.L.DeviceMenuView_EMPTY_HINT
            case .simulator: R.L.EmptyStateView_NO_SIMULATORS_HINT
        }
    }

    private func openSimulator() {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iphonesimulator") else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }
}
