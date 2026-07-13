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

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let middleClickEventTap = MiddleClickEventTap()
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?
    private var actionMenuItem: NSMenuItem!

    // Deliberately not persisted: launching the app always means the user wants
    // the mapping enabled.
    private var isEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()

        if !AccessibilityPermission.isTrusted {
            presentAuthorizationIntroduction()
        }

        refreshEngineAndMenu()
        let timer = Timer.scheduledTimer(
            timeInterval: 1.5,
            target: self,
            selector: #selector(refreshEngineAndMenu),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = 0.5
        permissionTimer = timer
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        middleClickEventTap.stop()
    }

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = statusImage()
        statusItem.button?.image?.isTemplate = true

        let menu = NSMenu()

        actionMenuItem = NSMenuItem(
            title: "",
            action: #selector(performPrimaryAction),
            keyEquivalent: ""
        )
        actionMenuItem.target = self
        menu.addItem(actionMenuItem)

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

    @objc private func refreshEngineAndMenu() {
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
}

private func localized(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
