import CoreGraphics
import XCTest
@testable import MacMiddleClick

final class MiddleClickEventConverterTests: XCTestCase {
    private var eventConverter: MiddleClickEventConverter!

    override func setUp() {
        super.setUp()
        eventConverter = MiddleClickEventConverter()
    }

    override func tearDown() {
        eventConverter = nil
        super.tearDown()
    }

    func testFnMouseDownBecomesMiddleMouseDown() throws {
        let event = try makeEvent(type: .leftMouseDown)
        event.flags = [.maskSecondaryFn, .maskShift]

        eventConverter.process(type: .leftMouseDown, event: event)

        XCTAssertEqual(event.type, .otherMouseDown)
        XCTAssertEqual(event.getIntegerValueField(.mouseEventButtonNumber), 2)
        XCTAssertFalse(event.flags.contains(.maskSecondaryFn))
        XCTAssertTrue(event.flags.contains(.maskShift))
    }

    func testCompleteFnDragSequenceBecomesMiddleMouseSequence() throws {
        let down = try makeEvent(type: .leftMouseDown)
        down.flags = [.maskSecondaryFn]
        eventConverter.process(type: .leftMouseDown, event: down)

        let drag = try makeEvent(type: .leftMouseDragged)
        eventConverter.process(type: .leftMouseDragged, event: drag)

        let up = try makeEvent(type: .leftMouseUp)
        eventConverter.process(type: .leftMouseUp, event: up)

        XCTAssertEqual(down.type, .otherMouseDown)
        XCTAssertEqual(drag.type, .otherMouseDragged)
        XCTAssertEqual(up.type, .otherMouseUp)
        XCTAssertEqual(drag.getIntegerValueField(.mouseEventButtonNumber), 2)
        XCTAssertEqual(up.getIntegerValueField(.mouseEventButtonNumber), 2)
    }

    func testPlainLeftClickIsNotModified() throws {
        let down = try makeEvent(type: .leftMouseDown)
        let up = try makeEvent(type: .leftMouseUp)

        eventConverter.process(type: .leftMouseDown, event: down)
        eventConverter.process(type: .leftMouseUp, event: up)

        XCTAssertEqual(down.type, .leftMouseDown)
        XCTAssertEqual(up.type, .leftMouseUp)
        XCTAssertEqual(down.getIntegerValueField(.mouseEventButtonNumber), 0)
    }

    func testFnPressedAfterMouseDownDoesNotModifyGesture() throws {
        let down = try makeEvent(type: .leftMouseDown)
        eventConverter.process(type: .leftMouseDown, event: down)

        let drag = try makeEvent(type: .leftMouseDragged)
        drag.flags = [.maskSecondaryFn]
        eventConverter.process(type: .leftMouseDragged, event: drag)

        let up = try makeEvent(type: .leftMouseUp)
        up.flags = [.maskSecondaryFn]
        eventConverter.process(type: .leftMouseUp, event: up)

        XCTAssertEqual(drag.type, .leftMouseDragged)
        XCTAssertEqual(up.type, .leftMouseUp)
    }

    func testConversionPreservesLocationAndTimestamp() throws {
        let event = try makeEvent(type: .leftMouseDown, location: CGPoint(x: 123, y: 456))
        event.flags = [.maskSecondaryFn]
        event.timestamp = 987_654

        eventConverter.process(type: .leftMouseDown, event: event)

        XCTAssertEqual(event.location.x, 123)
        XCTAssertEqual(event.location.y, 456)
        XCTAssertEqual(event.timestamp, 987_654)
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
