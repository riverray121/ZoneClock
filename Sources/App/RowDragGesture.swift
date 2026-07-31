import SwiftUI
import UIKit

/// Hold-then-drag backed by a UIKit long-press recognizer. UIKit's gesture
/// arbitration gives the native feel a pure SwiftUI sequenced gesture cannot:
/// moving before the hold completes lets the scroll view scroll, while a
/// completed hold locks scrolling out for the duration of the drag.
struct RowDragGesture: UIGestureRecognizerRepresentable {
    let onBegan: () -> Void
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void
    let onCancelled: () -> Void

    final class Coordinator {
        var startY: CGFloat?
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0.3
        recognizer.allowableMovement = 12
        return recognizer
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: UILongPressGestureRecognizer, context: Context
    ) {
        let y = recognizer.location(in: nil).y
        switch recognizer.state {
        case .began:
            context.coordinator.startY = y
            onBegan()
        case .changed:
            guard let start = context.coordinator.startY else { return }
            onChanged(y - start)
        case .ended:
            let start = context.coordinator.startY
            context.coordinator.startY = nil
            if let start {
                onEnded(y - start)
            } else {
                onCancelled()
            }
        default:
            context.coordinator.startY = nil
            onCancelled()
        }
    }
}
