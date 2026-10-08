import AppKit
import SwiftUI

/// Reports when the hosting MenuBarExtra panel is shown or hidden; `onAppear` is not reliable for
/// window-style menu bar content because the view hierarchy outlives a single presentation.
struct WindowVisibilityObserver: NSViewRepresentable {

    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ObservingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        (view as? ObservingView)?.onChange = onChange
    }

    private final class ObservingView: NSView {

        var onChange: ((Bool) -> Void)?
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            observers.forEach(NotificationCenter.default.removeObserver)
            observers = []
            guard let window else { return }

            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in self?.onChange?(true) },
                center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in self?.onChange?(false) },
                center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in self?.onChange?(false) },
            ]
            if window.isKeyWindow { onChange?(true) }
        }
    }
}
