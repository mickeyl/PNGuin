import AppKit
import SwiftUI

struct LastCaptureView: View {

    let record: CaptureRecord
    let model: AppModel

    var body: some View {
        HStack(spacing: Metrics.rowGap) {
            Image(nsImage: record.image)
                .resizable()
                .scaledToFit()
                .frame(height: Metrics.thumbnailHeight)
                .clipShape(.rect(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                Text(R.L.LastCaptureView_SAVED(record.url.lastPathComponent))
                    .font(.rowDetail)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: Metrics.rowGap) {
                    Button(R.L.LastCaptureView_REVEAL) { NSWorkspace.shared.activateFileViewerSelecting([record.url]) }
                    Button(R.L.LastCaptureView_COPY) { model.copy(record.image) }
                    Button(R.L.LastCaptureView_OPEN) { NSWorkspace.shared.open(record.url) }
                }
                .buttonStyle(.link)
                .font(.rowDetail)
            }
            Spacer(minLength: 0)
        }
    }
}
