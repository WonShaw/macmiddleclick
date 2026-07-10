import CoreGraphics
import Foundation

/// Converts Fn + left-button input into a standard middle-button event.
final class MiddleClickEventTap {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isConvertingClick = false

    var isRunning: Bool {
        eventTap != nil
    }

    @discardableResult
    func start() -> Bool {
        if isRunning {
            return true
        }

        let eventTypes: [CGEventType] = [
            .leftMouseDown,
            .leftMouseDragged,
            .leftMouseUp,
        ]
        let eventMask = eventTypes.reduce(CGEventMask(0)) { mask, type in
            mask | (CGEventMask(1) << type.rawValue)
        }

        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: middleClickEventTapCallback,
            userInfo: userInfo
        ) else {
            return false
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            CFMachPortInvalidate(tap)
            return false
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        isConvertingClick = false

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .leftMouseDown:
            guard event.flags.contains(.maskSecondaryFn) else {
                return Unmanaged.passUnretained(event)
            }
            isConvertingClick = true
            convert(event, to: .otherMouseDown)

        case .leftMouseDragged:
            guard isConvertingClick else {
                return Unmanaged.passUnretained(event)
            }
            convert(event, to: .otherMouseDragged)

        case .leftMouseUp:
            guard isConvertingClick else {
                return Unmanaged.passUnretained(event)
            }
            convert(event, to: .otherMouseUp)
            isConvertingClick = false

        default:
            break
        }

        return Unmanaged.passUnretained(event)
    }

    private func convert(_ event: CGEvent, to type: CGEventType) {
        var flags = event.flags
        flags.remove(.maskSecondaryFn)

        event.flags = flags
        event.type = type
        event.setIntegerValueField(.mouseEventButtonNumber, value: 2)
    }
}

private func middleClickEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let eventTap = Unmanaged<MiddleClickEventTap>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return eventTap.handle(type: type, event: event)
}
