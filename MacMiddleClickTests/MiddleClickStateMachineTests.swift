import CoreGraphics
import XCTest
@testable import MacMiddleClick

final class MiddleClickStateMachineTests: XCTestCase {
    func testPlainLeftClickPassesThrough() {
        var stateMachine = MiddleClickStateMachine()

        XCTAssertEqual(
            stateMachine.process(type: .leftMouseDown, flags: []),
            .passThrough
        )
        XCTAssertFalse(stateMachine.isConverting)
        XCTAssertEqual(
            stateMachine.process(type: .leftMouseUp, flags: []),
            .passThrough
        )
        XCTAssertFalse(stateMachine.isConverting)
    }

    func testFnLeftClickConvertsDownAndUp() {
        var stateMachine = MiddleClickStateMachine()

        XCTAssertEqual(
            stateMachine.process(type: .leftMouseDown, flags: [.maskSecondaryFn]),
            .convert(to: .otherMouseDown)
        )
        XCTAssertTrue(stateMachine.isConverting)
        XCTAssertEqual(
            stateMachine.process(type: .leftMouseUp, flags: [.maskSecondaryFn]),
            .convert(to: .otherMouseUp)
        )
        XCTAssertFalse(stateMachine.isConverting)
    }

    func testDragRemainsConvertedAfterFnIsReleased() {
        var stateMachine = MiddleClickStateMachine()

        _ = stateMachine.process(type: .leftMouseDown, flags: [.maskSecondaryFn])
        XCTAssertEqual(
            stateMachine.process(type: .leftMouseDragged, flags: []),
            .convert(to: .otherMouseDragged)
        )
        XCTAssertEqual(
            stateMachine.process(type: .leftMouseUp, flags: []),
            .convert(to: .otherMouseUp)
        )
        XCTAssertFalse(stateMachine.isConverting)
    }

    func testPressingFnAfterMouseDownDoesNotStartConversion() {
        var stateMachine = MiddleClickStateMachine()

        _ = stateMachine.process(type: .leftMouseDown, flags: [])
        XCTAssertEqual(
            stateMachine.process(type: .leftMouseDragged, flags: [.maskSecondaryFn]),
            .passThrough
        )
        XCTAssertEqual(
            stateMachine.process(type: .leftMouseUp, flags: [.maskSecondaryFn]),
            .passThrough
        )
    }

    func testNewPlainMouseDownCancelsStaleConversion() {
        var stateMachine = MiddleClickStateMachine()

        _ = stateMachine.process(type: .leftMouseDown, flags: [.maskSecondaryFn])
        XCTAssertTrue(stateMachine.isConverting)
        XCTAssertEqual(
            stateMachine.process(type: .leftMouseDown, flags: []),
            .passThrough
        )
        XCTAssertFalse(stateMachine.isConverting)
    }

    func testResetCancelsConversion() {
        var stateMachine = MiddleClickStateMachine()

        _ = stateMachine.process(type: .leftMouseDown, flags: [.maskSecondaryFn])
        stateMachine.reset()

        XCTAssertFalse(stateMachine.isConverting)
        XCTAssertEqual(
            stateMachine.process(type: .leftMouseUp, flags: []),
            .passThrough
        )
    }

    func testUnrelatedEventPassesThroughWithoutChangingState() {
        var stateMachine = MiddleClickStateMachine()

        _ = stateMachine.process(type: .leftMouseDown, flags: [.maskSecondaryFn])
        XCTAssertEqual(
            stateMachine.process(type: .scrollWheel, flags: []),
            .passThrough
        )
        XCTAssertTrue(stateMachine.isConverting)
    }
}
