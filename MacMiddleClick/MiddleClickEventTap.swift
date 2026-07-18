import CoreGraphics
import Foundation

/// Converts Fn + left-button input into a standard middle-button event.
final class MiddleClickEventTap {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var observesInvalidation = false
    private let eventConverter = MiddleClickEventConverter()
    var onInterruption: (() -> Void)?

    var isRunning: Bool {
        guard let eventTap else {
            return false
        }
        return CFMachPortIsValid(eventTap)
            && CGEvent.tapIsEnabled(tap: eventTap)
    }

    deinit {
        stop()
    }

    @discardableResult
    func start() -> Bool {
        if let eventTap {
            if CFMachPortIsValid(eventTap) {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                if isRunning {
                    return true
                }
            }
            stop()
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
        installInvalidationCallback(for: tap, userInfo: userInfo)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        guard isRunning else {
            stop()
            return false
        }
        return true
    }

    func stop() {
        eventConverter.reset()

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }

        if let tap = eventTap {
            eventTap = nil
            if observesInvalidation {
                CFMachPortSetInvalidationCallBack(tap, nil)
                observesInvalidation = false
            }
            if CFMachPortIsValid(tap) {
                CGEvent.tapEnable(tap: tap, enable: false)
                CFMachPortInvalidate(tap)
            }
        }
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            eventConverter.reset()
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            onInterruption?()
            return Unmanaged.passUnretained(event)
        }

        return Unmanaged.passUnretained(eventConverter.process(type: type, event: event))
    }

    private func installInvalidationCallback(
        for tap: CFMachPort,
        userInfo: UnsafeMutableRawPointer
    ) {
        var context = CFMachPortContext(
            version: 0,
            info: nil,
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        CFMachPortGetContext(tap, &context)
        guard context.info == userInfo,
              CFMachPortGetInvalidationCallBack(tap) == nil else {
            return
        }

        CFMachPortSetInvalidationCallBack(
            tap,
            middleClickEventTapInvalidationCallback
        )
        observesInvalidation = true
    }

    fileprivate func handleInvalidation(_ invalidatedTap: CFMachPort?) {
        guard let invalidatedTap, let eventTap, eventTap === invalidatedTap else {
            return
        }

        eventConverter.reset()
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        self.eventTap = nil
        observesInvalidation = false
        onInterruption?()
    }
}

private func middleClickEventTapInvalidationCallback(
    invalidatedTap: CFMachPort?,
    userInfo: UnsafeMutableRawPointer?
) {
    guard let userInfo else {
        return
    }

    let eventTap = Unmanaged<MiddleClickEventTap>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    DispatchQueue.main.async { [weak eventTap] in
        eventTap?.handleInvalidation(invalidatedTap)
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
