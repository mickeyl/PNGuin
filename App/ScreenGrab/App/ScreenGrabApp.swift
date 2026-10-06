import SwiftUI

@main
struct ScreenGrabApp: App {

    @State private var model: AppModel

    init() {
        _model = State(initialValue: AppModel())
    }

    var body: some Scene {
        MenuBarExtra("ScreenGrab", systemImage: "iphone.gen3") {
            DeviceMenuView(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}
