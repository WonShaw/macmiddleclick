import Foundation
import ServiceManagement
import XCTest
@testable import MacMiddleClick

final class LaunchAtLoginControllerTests: XCTestCase {
    func testSystemStatusesAreMapped() {
        XCTAssertEqual(
            LaunchAtLoginStatus(systemStatus: .notRegistered),
            .notRegistered
        )
        XCTAssertEqual(
            LaunchAtLoginStatus(systemStatus: .enabled),
            .enabled
        )
        XCTAssertEqual(
            LaunchAtLoginStatus(systemStatus: .requiresApproval),
            .requiresApproval
        )
        XCTAssertEqual(
            LaunchAtLoginStatus(systemStatus: .notFound),
            .notFound
        )
    }

    func testPreferenceDefaultsToEnabled() throws {
        let suiteName = "LaunchAtLoginControllerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let preference = UserDefaultsLaunchAtLoginPreference(
            defaults: defaults
        )

        XCTAssertTrue(preference.isEnabled)
    }

    func testPreferencePersistsExplicitlyDisabledState() throws {
        let suiteName = "LaunchAtLoginControllerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preference = UserDefaultsLaunchAtLoginPreference(
            defaults: defaults
        )

        preference.isEnabled = false

        XCTAssertFalse(
            UserDefaultsLaunchAtLoginPreference(defaults: defaults).isEnabled
        )
    }

    func testLaunchRegistersWhenPreferenceIsEnabled() {
        let service = MockLaunchAtLoginService(status: .notRegistered)
        service.statusAfterRegister = .enabled
        let preference = MockLaunchAtLoginPreference(isEnabled: true)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        controller.synchronizeAtLaunch()

        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertTrue(controller.isEnabledByUser)
        XCTAssertNil(controller.attention)
    }

    func testLaunchDoesNotRegisterWhenPreferenceIsDisabled() {
        let service = MockLaunchAtLoginService(status: .notRegistered)
        let preference = MockLaunchAtLoginPreference(isEnabled: false)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        controller.synchronizeAtLaunch()

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertNil(controller.attention)
    }

    func testDisabledPreferenceIgnoresMissingService() {
        let service = MockLaunchAtLoginService(status: .notFound)
        let preference = MockLaunchAtLoginPreference(isEnabled: false)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        controller.synchronizeAtLaunch()

        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertEqual(service.unregisterCallCount, 0)
        XCTAssertNil(controller.attention)
    }

    func testLaunchUnregistersExistingServiceWhenPreferenceIsDisabled() {
        let service = MockLaunchAtLoginService(status: .enabled)
        let preference = MockLaunchAtLoginPreference(isEnabled: false)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        controller.synchronizeAtLaunch()

        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertEqual(service.registerCallCount, 0)
        XCTAssertNil(controller.attention)
    }

    func testToggleOffPersistsPreferenceAndUnregisters() throws {
        let service = MockLaunchAtLoginService(status: .enabled)
        let preference = MockLaunchAtLoginPreference(isEnabled: true)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        try controller.toggle()

        XCTAssertFalse(preference.isEnabled)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertNil(controller.attention)
    }

    func testToggleOffFailurePreservesEnabledPreference() {
        let service = MockLaunchAtLoginService(status: .enabled)
        service.unregisterError = TestError.registrationFailed
        let preference = MockLaunchAtLoginPreference(isEnabled: true)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        XCTAssertThrowsError(try controller.toggle())

        XCTAssertTrue(preference.isEnabled)
        XCTAssertEqual(service.unregisterCallCount, 1)
        XCTAssertNil(controller.attention)
    }

    func testToggleOnPersistsPreferenceAndRegisters() throws {
        let service = MockLaunchAtLoginService(status: .notRegistered)
        service.statusAfterRegister = .enabled
        let preference = MockLaunchAtLoginPreference(isEnabled: false)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        try controller.toggle()

        XCTAssertTrue(preference.isEnabled)
        XCTAssertEqual(service.registerCallCount, 1)
        XCTAssertNil(controller.attention)
    }

    func testApprovalRequirementShowsAttentionOnlyWhileEnabledByUser() {
        let service = MockLaunchAtLoginService(status: .requiresApproval)
        let preference = MockLaunchAtLoginPreference(isEnabled: true)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        XCTAssertEqual(controller.attention, .requiresApproval)

        preference.isEnabled = false
        XCTAssertNil(controller.attention)
    }

    func testApprovalAttentionOpensSystemSettings() {
        let service = MockLaunchAtLoginService(status: .requiresApproval)
        let preference = MockLaunchAtLoginPreference(isEnabled: true)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        controller.performAttentionAction()

        XCTAssertEqual(service.openSettingsCallCount, 1)
        XCTAssertEqual(service.registerCallCount, 0)
    }

    func testRegistrationFailureShowsRetryAttention() {
        let service = MockLaunchAtLoginService(status: .notRegistered)
        service.registerError = TestError.registrationFailed
        let preference = MockLaunchAtLoginPreference(isEnabled: true)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        controller.synchronizeAtLaunch()

        XCTAssertEqual(controller.attention, .registrationFailed)
        XCTAssertEqual(service.registerCallCount, 1)
    }

    func testLaunchDeniedErrorShowsApprovalAttention() {
        let service = MockLaunchAtLoginService(status: .notRegistered)
        service.registerError = NSError(
            domain: "LaunchAtLoginControllerTests",
            code: kSMErrorLaunchDeniedByUser
        )
        let preference = MockLaunchAtLoginPreference(isEnabled: true)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        controller.synchronizeAtLaunch()
        XCTAssertEqual(controller.attention, .requiresApproval)

        controller.performAttentionAction()
        XCTAssertEqual(service.openSettingsCallCount, 1)
    }

    func testRetryAttentionAttemptsRegistrationAgain() {
        let service = MockLaunchAtLoginService(status: .notRegistered)
        service.registerError = TestError.registrationFailed
        let preference = MockLaunchAtLoginPreference(isEnabled: true)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )
        controller.synchronizeAtLaunch()
        service.registerError = nil
        service.statusAfterRegister = .enabled

        controller.performAttentionAction()

        XCTAssertEqual(service.registerCallCount, 2)
        XCTAssertNil(controller.attention)
    }

    func testSuccessfulRegistrationThatRequiresApprovalShowsAttention() {
        let service = MockLaunchAtLoginService(status: .notRegistered)
        service.statusAfterRegister = .requiresApproval
        let preference = MockLaunchAtLoginPreference(isEnabled: true)
        let controller = LaunchAtLoginController(
            service: service,
            preference: preference
        )

        controller.synchronizeAtLaunch()

        XCTAssertEqual(controller.attention, .requiresApproval)
        XCTAssertEqual(service.openSettingsCallCount, 0)
    }
}

private final class MockLaunchAtLoginService: LaunchAtLoginServicing {
    var status: LaunchAtLoginStatus
    var statusAfterRegister: LaunchAtLoginStatus?
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var openSettingsCallCount = 0

    init(status: LaunchAtLoginStatus) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        if let statusAfterRegister {
            status = statusAfterRegister
        }
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        status = .notRegistered
    }

    func openSystemSettings() {
        openSettingsCallCount += 1
    }
}

private final class MockLaunchAtLoginPreference:
    LaunchAtLoginPreferenceStoring {
    var isEnabled: Bool

    init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }
}

private enum TestError: Error, Equatable {
    case registrationFailed
}
