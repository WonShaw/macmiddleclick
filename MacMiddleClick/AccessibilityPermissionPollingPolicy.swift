import Foundation

enum AccessibilityPermissionPollingPolicy {
    struct Schedule: Equatable {
        let interval: TimeInterval
        let tolerance: TimeInterval
    }

    static func schedule(isTrusted: Bool) -> Schedule {
        isTrusted
            ? Schedule(interval: 60, tolerance: 5)
            : Schedule(interval: 2, tolerance: 0.2)
    }
}
