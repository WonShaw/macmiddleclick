import CoreGraphics
import XCTest
@testable import MacMiddleClick

final class MiddleClickEventTapTests: XCTestCase {
    func testStopClearsAnActiveConversion() throws {
        let eventTap = MiddleClickEventTap()
        let down = try makeEvent(type: .leftMouseDown)
        down.flags = [.maskSecondaryFn]
        _ = eventTap.handle(type: .leftMouseDown, event: down)

        eventTap.stop()

        let up = try makeEvent(type: .leftMouseUp)
        _ = eventTap.handle(type: .leftMouseUp, event: up)
        XCTAssertEqual(up.type, .leftMouseUp)
    }

    func testDisabledTapEventsClearAnActiveConversion() throws {
        for disabledType in [CGEventType.tapDisabledByTimeout, .tapDisabledByUserInput] {
            let eventTap = MiddleClickEventTap()
            let down = try makeEvent(type: .leftMouseDown)
            down.flags = [.maskSecondaryFn]
            _ = eventTap.handle(type: .leftMouseDown, event: down)

            let disabledEvent = try makeEvent(type: .mouseMoved)
            _ = eventTap.handle(type: disabledType, event: disabledEvent)

            let up = try makeEvent(type: .leftMouseUp)
            _ = eventTap.handle(type: .leftMouseUp, event: up)
            XCTAssertEqual(up.type, .leftMouseUp)
        }
    }

    func testDisabledTapEventsRequestAStateRefresh() throws {
        for disabledType in [CGEventType.tapDisabledByTimeout, .tapDisabledByUserInput] {
            let eventTap = MiddleClickEventTap()
            var refreshCount = 0
            eventTap.onInterruption = {
                refreshCount += 1
            }

            let disabledEvent = try makeEvent(type: .mouseMoved)
            _ = eventTap.handle(type: disabledType, event: disabledEvent)

            XCTAssertEqual(refreshCount, 1)
        }
    }

    func testDeinitStopsAndReleasesEventTap() {
        weak var weakEventTap: MiddleClickEventTap?

        autoreleasepool {
            let eventTap = MiddleClickEventTap()
            weakEventTap = eventTap
        }

        XCTAssertNil(weakEventTap)
    }

    private func makeEvent(
        type: CGEventType,
        location: CGPoint = .zero
    ) throws -> CGEvent {
        try XCTUnwrap(
            CGEvent(
                mouseEventSource: nil,
                mouseType: type,
                mouseCursorPosition: location,
                mouseButton: .left
            )
        )
    }
}
