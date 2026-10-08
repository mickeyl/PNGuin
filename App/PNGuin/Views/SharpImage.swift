import AppKit
import SwiftUI
import PNGuinKit

/// Shows `image` scaled to fit, but rendered from a Lanczos-downsampled copy that matches the backing pixels exactly.
/// Callers keep `image` itself for copying and exporting.
struct SharpImage: View {

    let image: NSImage

    @Environment(\.displayScale) private var displayScale
    @State private var renderedSize: CGSize = .zero
    @State private var sharp: Sharp?

    private struct Sharp {
        let source: NSImage
        let image: NSImage
    }

    private struct Request: Equatable {
        let source: NSImage
        let width: Int
        let height: Int

        // Holding `source` strongly keeps its address from being reused by the next capture, so identity is a safe key.
        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.source === rhs.source && lhs.width == rhs.width && lhs.height == rhs.height
        }
    }

    var body: some View {
        Image(nsImage: displayed)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .onGeometryChange(for: CGSize.self, of: \.size) { renderedSize = $0 }
            .task(id: request) { await downsample(request) }
    }

    private var displayed: NSImage {
        guard let sharp, sharp.source === image else { return image }
        return sharp.image
    }

    private var request: Request {
        Request(source: image, width: Int((renderedSize.width * displayScale).rounded()), height: Int((renderedSize.height * displayScale).rounded()))
    }

    private func downsample(_ request: Request) async {
        guard
            let source = request.source.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let scaled = await ImageScaler.scaled(source, width: request.width, height: request.height),
            !Task.isCancelled
        else { return }
        sharp = Sharp(source: request.source, image: NSImage(cgImage: scaled, size: CGSize(width: CGFloat(request.width) / displayScale, height: CGFloat(request.height) / displayScale)))
    }
}
