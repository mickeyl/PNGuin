import SwiftUI
import ScreenGrabKit

enum Metrics {
    static let popoverWidth: CGFloat = 340
    static let inset: CGFloat = 12
    static let rowGap: CGFloat = 8
    static let sectionGap: CGFloat = 12
    static let rowHeight: CGFloat = 44
    static let iconColumnWidth: CGFloat = 28
    static let previewHeight: CGFloat = 320
    static let previewCornerRadius: CGFloat = 14
    static let thumbnailHeight: CGFloat = 44
    /// The icon canvas has a built-in margin, so 32 pt shows a squircle about as tall as the segmented control.
    static let headerIconSize: CGFloat = 32
}

extension Font {
    static let rowTitle = Font.body.weight(.medium)
    static let rowDetail = Font.caption
    static let statusNote = Font.callout
    static let fieldLabel = Font.callout
}

extension Device.Availability {

    var tint: Color {
        switch self {
            case .ready: .green
            case .locked: .orange
            case .unreachable: .secondary
            case .unknown: .secondary
        }
    }

    var title: String {
        switch self {
            case .ready: R.L.DeviceRow_STATE_READY
            case .locked: R.L.DeviceRow_STATE_LOCKED
            case .unreachable: R.L.DeviceRow_STATE_UNREACHABLE
            case .unknown: R.L.DeviceRow_STATE_UNKNOWN
        }
    }
}

extension Device {

    var symbolName: String {
        switch kind {
            case .iPhone: "iphone"
            case .iPad: "ipad"
        }
    }
}
