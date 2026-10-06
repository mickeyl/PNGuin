import SwiftUI
import ScreenGrabKit

struct PreviewView: View {

    let state: AppModel.PreviewState

    var body: some View {
        ZStack {
            switch state {
                case .none:
                    note(R.L.PreviewView_NONE)
                case .loading:
                    VStack(spacing: Metrics.rowGap) {
                        ProgressView().controlSize(.small)
                        Text(R.L.PreviewView_LOADING).font(.statusNote).foregroundStyle(.secondary)
                    }
                case .image(let image):
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(.rect(cornerRadius: Metrics.previewCornerRadius))
                case .unavailable(.locked):
                    note(R.L.PreviewView_LOCKED)
                case .unavailable:
                    note(R.L.PreviewView_UNREACHABLE)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.previewHeight)
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.statusNote).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
}
