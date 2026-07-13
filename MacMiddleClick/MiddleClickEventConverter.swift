import CoreGraphics

/// Applies middle-button conversion decisions to concrete Core Graphics events.
final class MiddleClickEventConverter {
    private var stateMachine = MiddleClickStateMachine()

    @discardableResult
    func process(type: CGEventType, event: CGEvent) -> CGEvent {
        switch stateMachine.process(type: type, flags: event.flags) {
        case .passThrough:
            return event
        case .convert(to: let convertedType):
            convert(event, to: convertedType)
            return event
        }
    }

    func reset() {
        stateMachine.reset()
    }

    private func convert(_ event: CGEvent, to type: CGEventType) {
        var flags = event.flags
        flags.remove(.maskSecondaryFn)

        event.flags = flags
        event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
    }
}
