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

/// Pan that only recognizes horizontal drags: vertical movement fails it
/// while still possible, so the scroll view keeps vertical pans.
final class HorizontalPanRecognizer: UIPanGestureRecognizer {
    private var initialTouch: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        initialTouch = touches.first?.location(in: view?.window)
        super.touchesBegan(touches, with: event)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        if state == .possible,
           let start = initialTouch,
           let current = touches.first?.location(in: view?.window) {
            let dx = abs(current.x - start.x)
            let dy = abs(current.y - start.y)
            if dy > 8, dy > dx {
                state = .failed
                return
            }
        }
        super.touchesMoved(touches, with: event)
    }

    override func reset() {
        initialTouch = nil
        super.reset()
    }
}

/// Mail-style row swipe for revealing action buttons.
struct RowSwipeGesture: UIGestureRecognizerRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: (CGFloat) -> Void
    let onCancelled: () -> Void

    final class Coordinator {}

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> HorizontalPanRecognizer {
        let recognizer = HorizontalPanRecognizer()
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }

    func handleUIGestureRecognizerAction(
        _ recognizer: HorizontalPanRecognizer, context: Context
    ) {
        let translation = recognizer.translation(in: recognizer.view).x
        switch recognizer.state {
        case .changed: onChanged(translation)
        case .ended: onEnded(translation)
        case .cancelled, .failed: onCancelled()
        default: break
        }
    }
}
