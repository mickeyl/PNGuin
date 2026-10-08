import SwiftUI
import ScreenGrabKit

struct PreviewView: View {

    let state: AppModel.PreviewState
    let copy: () -> Void
    let dragItem: () -> NSItemProvider

    @State private var copies = 0
    @State private var showsCopied = false

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
                        .overlay(alignment: .bottom) { if showsCopied { copiedBadge } }
                        .onTapGesture(perform: didTap)
                        .onDrag(dragItem)
                        .help(R.L.PreviewView_HELP)
                        .accessibilityElement()
                        .accessibilityLabel(R.L.PreviewView_ACCESSIBILITY_LABEL)
                        .accessibilityHint(R.L.PreviewView_HELP)
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { didTap() }
                case .unavailable(.locked):
                    note(R.L.PreviewView_LOCKED)
                case .unavailable:
                    note(R.L.PreviewView_UNREACHABLE)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Metrics.previewHeight)
        .task(id: copies) {
            guard copies > 0 else { return }
            // A newer tap cancels this task and restarts the timer; hiding here would make the badge flicker.
            do { try await Task.sleep(for: .seconds(1.2)) } catch { return }
            withAnimation { showsCopied = false }
        }
    }

    private var copiedBadge: some View {
        Label(R.L.PreviewView_COPIED, systemImage: "checkmark")
            .font(.statusNote)
            .padding(.horizontal, Metrics.rowGap * 1.5)
            .padding(.vertical, Metrics.rowGap / 2)
            .glassEffect(.regular, in: .capsule)
            .padding(.bottom, Metrics.rowGap)
            .transition(.opacity)
    }

    private func didTap() {
        copy()
        copies += 1
        withAnimation { showsCopied = true }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(.statusNote).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }
}
