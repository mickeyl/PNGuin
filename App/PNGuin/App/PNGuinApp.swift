import SwiftUI

@main
struct PNGuinApp: App {

    @State private var model: AppModel

    init() {
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        MenuBarExtra("PNGuin", systemImage: "iphone.gen3") {
            DeviceMenuView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
