import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound

    init(systemStatus: SMAppService.Status) {
        switch systemStatus {
        case .notRegistered:
            self = .notRegistered
        case .enabled:
            self = .enabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .notFound
        @unknown default:
            self = .notFound
        }
    }
}

enum LaunchAtLoginAttention: Equatable {
    case requiresApproval
    case registrationFailed
}

protocol LaunchAtLoginServicing: AnyObject {
    var status: LaunchAtLoginStatus { get }

    func register() throws
    func unregister() throws
    func openSystemSettings()
}

protocol LaunchAtLoginPreferenceStoring: AnyObject {
    var isEnabled: Bool { get set }
}

final class SystemLaunchAtLoginService: LaunchAtLoginServicing {
    private let service = SMAppService.mainApp

    var status: LaunchAtLoginStatus {
        LaunchAtLoginStatus(systemStatus: service.status)
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

final class UserDefaultsLaunchAtLoginPreference:
    LaunchAtLoginPreferenceStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "launchAtLoginEnabled"
    ) {
        self.defaults = defaults
        self.key = key
    }

    var isEnabled: Bool {
        get {
            guard defaults.object(forKey: key) != nil else {
                return true
            }
            return defaults.bool(forKey: key)
        }
        set {
            defaults.set(newValue, forKey: key)
        }
    }
}

final class LaunchAtLoginController {
    private let service: LaunchAtLoginServicing
    private let preference: LaunchAtLoginPreferenceStoring
    private var registrationAttention: LaunchAtLoginAttention?

    init(
        service: LaunchAtLoginServicing = SystemLaunchAtLoginService(),
        preference: LaunchAtLoginPreferenceStoring =
            UserDefaultsLaunchAtLoginPreference()
    ) {
        self.service = service
        self.preference = preference
    }

    /// The persisted user preference, independent of the current system status.
    var isEnabledByUser: Bool {
        preference.isEnabled
    }

    var attention: LaunchAtLoginAttention? {
        guard isEnabledByUser else {
            return nil
        }

        switch service.status {
        case .enabled:
            return nil
        case .requiresApproval:
            return .requiresApproval
        case .notRegistered, .notFound:
            return registrationAttention
        }
    }

    func synchronizeAtLaunch() {
        if isEnabledByUser {
            attemptRegistrationIfNeeded()
        } else {
            try? unregisterIfNeeded()
        }
    }

    func toggle() throws {
        if isEnabledByUser {
            try unregisterIfNeeded()
            preference.isEnabled = false
            registrationAttention = nil
        } else {
            preference.isEnabled = true
            attemptRegistrationIfNeeded()
        }
    }

    func performAttentionAction() {
        switch attention {
        case .requiresApproval:
            service.openSystemSettings()
        case .registrationFailed:
            attemptRegistrationIfNeeded()
        case nil:
            break
        }
    }

    private func attemptRegistrationIfNeeded() {
        switch service.status {
        case .enabled, .requiresApproval:
            registrationAttention = nil

        case .notRegistered, .notFound:
            do {
                try service.register()
                switch service.status {
                case .enabled:
                    registrationAttention = nil
                case .requiresApproval:
                    registrationAttention = .requiresApproval
                case .notRegistered, .notFound:
                    registrationAttention = .registrationFailed
                }
            } catch {
                registrationAttention = (error as NSError).code
                    == kSMErrorLaunchDeniedByUser
                    ? .requiresApproval
                    : .registrationFailed
            }
        }
    }

    private func unregisterIfNeeded() throws {
        switch service.status {
        case .enabled, .requiresApproval:
            try service.unregister()
        case .notRegistered, .notFound:
            break
        }
    }
}
