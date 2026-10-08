import SwiftUI
import ScreenGrabKit

struct SourcePicker: View {

    let model: AppModel

    var body: some View {
        Picker(selection: Binding(get: { model.source }, set: { model.show($0) })) {
            ForEach(Device.Source.allCases, id: \.self) { source in
                Text(title(for: source)).tag(source)
            }
        } label: {
            EmptyView()
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private func title(for source: Device.Source) -> String {
        switch (source, model.count(of: source)) {
            case (.physical, let count?): R.L.SourcePicker_DEVICES_COUNT(count)
            case (.physical, nil): R.L.SourcePicker_DEVICES
            case (.simulator, let count?): R.L.SourcePicker_SIMULATORS_COUNT(count)
            case (.simulator, nil): R.L.SourcePicker_SIMULATORS
        }
    }
}
