import AppKit
import SwiftUI

struct SettingsView: View {

    @Bindable var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.rowGap) {
            Divider()
            HStack {
                Text(R.L.SettingsView_OUTPUT_FOLDER).font(.fieldLabel)
                Text(settings.outputDirectory.lastPathComponent)
                    .font(.fieldLabel)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button(R.L.SettingsView_CHOOSE, action: chooseFolder)
            }
            Toggle(R.L.SettingsView_COPY_TO_CLIPBOARD, isOn: $settings.copyToClipboard)
            Toggle(R.L.SettingsView_AUTO_REFRESH, isOn: $settings.autoRefreshPreview)
            Toggle(R.L.SettingsView_LAUNCH_AT_LOGIN, isOn: $settings.launchAtLogin)
            Text(R.L.SettingsView_SIMULATORS)
                .foregroundStyle(.secondary)
                .padding(.top, Metrics.rowGap / 2)
            Toggle(R.L.SettingsView_CLEAN_STATUS_BAR, isOn: $settings.cleanStatusBar)
            Toggle(R.L.SettingsView_MASK_CORNERS, isOn: $settings.maskCorners)
        }
        .font(.fieldLabel)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.directoryURL = settings.outputDirectory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.outputDirectory = url
    }
}
