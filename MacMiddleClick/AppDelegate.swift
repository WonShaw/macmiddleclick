import AppKit

@main
enum MacMiddleClickApplication {
    private static let appDelegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = appDelegate
        application.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let middleClickEventTap = MiddleClickEventTap()
    private let launchAtLoginController = LaunchAtLoginController()
    private var statusItem: NSStatusItem!
    private var workspaceActivationObserver: NSObjectProtocol?
    private var actionMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!
    private var launchAtLoginAttentionMenuItem: NSMenuItem!

    // Deliberately not persisted: launching the app always means the user wants
    // the mapping enabled.
    private var isEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configureEventDrivenPermissionChecks()
        launchAtLoginController.synchronizeAtLaunch()

        if !AccessibilityPermission.isTrusted {
            presentAuthorizationIntroduction()
        }

        refreshEngineAndMenu()
        refreshLaunchAtLoginMenu()
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let workspaceActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(
                workspaceActivationObserver
            )
            self.workspaceActivationObserver = nil
        }
        middleClickEventTap.onDisabled = nil
        middleClickEventTap.stop()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshEngineAndMenu()
        refreshLaunchAtLoginMenu()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = statusImage()
        statusItem.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self

        actionMenuItem = NSMenuItem(
            title: "",
            action: #selector(performPrimaryAction),
            keyEquivalent: ""
        )
        actionMenuItem.target = self
        menu.addItem(actionMenuItem)

        launchAtLoginMenuItem = NSMenuItem(
            title: "",
            action: #selector(performLaunchAtLoginAction),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self
        menu.addItem(launchAtLoginMenuItem)

        launchAtLoginAttentionMenuItem = NSMenuItem(
            title: "",
            action: #selector(performLaunchAtLoginAttentionAction),
            keyEquivalent: ""
        )
        launchAtLoginAttentionMenuItem.target = self
        launchAtLoginAttentionMenuItem.indentationLevel = 1
        launchAtLoginAttentionMenuItem.isHidden = true
        menu.addItem(launchAtLoginAttentionMenuItem)

        let creatorItem = NSMenuItem(
            title: localized("menu.creator"),
            action: nil,
            keyEquivalent: ""
        )
        creatorItem.isEnabled = false
        menu.addItem(creatorItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: localized("menu.quit"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func configureEventDrivenPermissionChecks() {
        middleClickEventTap.onDisabled = { [weak self] in
            // Avoid invalidating the tap while its callback is still running.
            DispatchQueue.main.async { [weak self] in
                self?.refreshEngineAndMenu()
            }
        }

        workspaceActivationObserver = NSWorkspace.shared.notificationCenter
            .addObserver(
                forName: NSWorkspace.didActivateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshEngineAndMenu()
            }
    }

    @objc private func performPrimaryAction() {
        if !AccessibilityPermission.isTrusted {
            // Re-requesting authorization always expresses an intent to enable.
            isEnabled = true
            AccessibilityPermission.request()
        } else if isEnabled && middleClickEventTap.isRunning {
            isEnabled = false
        } else {
            isEnabled = true
        }

        refreshEngineAndMenu()
    }

    @objc private func performLaunchAtLoginAction() {
        do {
            try launchAtLoginController.toggle()
        } catch {
            presentLaunchAtLoginError(error)
        }

        refreshLaunchAtLoginMenu()
    }

    @objc private func performLaunchAtLoginAttentionAction() {
        launchAtLoginController.performAttentionAction()
        refreshLaunchAtLoginMenu()
    }

    private func refreshEngineAndMenu() {
        let trusted = AccessibilityPermission.isTrusted

        if isEnabled && trusted {
            _ = middleClickEventTap.start()
        } else {
            middleClickEventTap.stop()
        }

        if !trusted {
            actionMenuItem.title = localized("menu.mapping.enable")
        } else if !isEnabled {
            actionMenuItem.title = localized("menu.mapping.disabled")
        } else if middleClickEventTap.isRunning {
            actionMenuItem.title = localized("menu.mapping.enabled")
        } else {
            actionMenuItem.title = localized("menu.mapping.retry")
        }

        statusItem.button?.image = statusImage()
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = actionMenuItem.title
    }

    private func refreshLaunchAtLoginMenu() {
        launchAtLoginMenuItem.title = localized("menu.launchAtLogin")
        launchAtLoginMenuItem.state = launchAtLoginController.isEnabledByUser
            ? .on
            : .off

        switch launchAtLoginController.attention {
        case .requiresApproval:
            launchAtLoginAttentionMenuItem.title = localized(
                "menu.launchAtLogin.openSettings"
            )
            launchAtLoginAttentionMenuItem.isHidden = false

        case .registrationFailed:
            launchAtLoginAttentionMenuItem.title = localized(
                "menu.launchAtLogin.retry"
            )
            launchAtLoginAttentionMenuItem.isHidden = false

        case nil:
            launchAtLoginAttentionMenuItem.isHidden = true
        }
    }

    private func statusImage() -> NSImage? {
        let symbolName = middleClickEventTap.isRunning
            ? "computermouse.fill"
            : "computermouse"
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: "MacMiddleClick")
    }

    private func presentAuthorizationIntroduction() {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = localized("authorization.title")
        alert.informativeText = localized("authorization.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: localized("authorization.confirm"))
        alert.addButton(withTitle: localized("common.cancel"))

        if alert.runModal() == .alertFirstButtonReturn {
            isEnabled = true
            AccessibilityPermission.request()
        }
    }

    private func presentLaunchAtLoginError(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = localized("launchAtLogin.error.title")
        alert.informativeText = String(
            format: localized("launchAtLogin.error.message"),
            error.localizedDescription
        )
        alert.alertStyle = .warning
        alert.addButton(withTitle: localized("common.ok"))
        alert.runModal()
    }
}

private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
