import SwiftUI
import UIKit

/// System share sheet for a file we just wrote (ShareLink can't be triggered after generating a file on tap).
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    /// Called when the sheet closes; `true` only if the person really sent or saved the file.
    var onComplete: ((Bool) -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in onComplete?(completed) }
        return controller
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
