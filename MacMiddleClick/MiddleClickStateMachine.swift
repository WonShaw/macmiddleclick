import CoreGraphics

/// Decides whether an incoming left-button event belongs to an Fn-click gesture.
///
/// The Fn modifier is only required when the button goes down. Once conversion
/// starts, drag and mouse-up events remain middle-button events even if Fn is
/// released before the mouse button.
struct MiddleClickStateMachine {
    enum Action: Equatable {
        case passThrough
        case convert(to: CGEventType)
    }

    private(set) var isConverting = false

    mutating func process(type: CGEventType, flags: CGEventFlags) -> Action {
        switch type {
        case .leftMouseDown:
            isConverting = flags.contains(.maskSecondaryFn)
            return isConverting ? .convert(to: .otherMouseDown) : .passThrough

        case .leftMouseDragged:
            return isConverting ? .convert(to: .otherMouseDragged) : .passThrough

        case .leftMouseUp:
            defer { isConverting = false }
            return isConverting ? .convert(to: .otherMouseUp) : .passThrough

        default:
            return .passThrough
        }
    }

    mutating func reset() {
        isConverting = false
    }
}
