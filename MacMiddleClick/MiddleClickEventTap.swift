import CoreGraphics
import Foundation

/// Converts Fn + left-button input into a standard middle-button event.
final class MiddleClickEventTap {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let eventConverter = MiddleClickEventConverter()

    var isRunning: Bool {
        eventTap != nil
    }

    deinit {
        stop()
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
        eventConverter.reset()

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

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            eventConverter.reset()
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        return Unmanaged.passUnretained(eventConverter.process(type: type, event: event))
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
