import AppKit

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let middleClickEventTap = MiddleClickEventTap()
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?
    private var actionMenuItem: NSMenuItem!

    // Deliberately not persisted: launching the app always means the user wants
    // the mapping enabled.
    private var isEnabled = true

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()

        if !AccessibilityPermission.isTrusted {
            presentAuthorizationIntroduction()
        }

        refreshEngineAndMenu()
        permissionTimer = Timer.scheduledTimer(
            timeInterval: 1.5,
            target: self,
            selector: #selector(refreshEngineAndMenu),
            userInfo: nil,
            repeats: true
        )
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

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "退出 MacMiddleClick",
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
            actionMenuItem.title = "Fn + 左键 → 中键：点击启用"
        } else if !isEnabled {
            actionMenuItem.title = "Fn + 左键 → 中键：已禁用"
        } else if middleClickEventTap.isRunning {
            actionMenuItem.title = "Fn + 左键 → 中键：已启用"
        } else {
            actionMenuItem.title = "Fn + 左键 → 中键：启用失败，点击重试"
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
        alert.messageText = "使用 Fn + 左键模拟鼠标中键"
        alert.informativeText = "按住 Fn，再点击或拖动鼠标左键（包括触摸板左键），即可发送鼠标中键。此功能需要开启 macOS“辅助功能”权限。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "好，去授权")
        alert.addButton(withTitle: "取消")

        if alert.runModal() == .alertFirstButtonReturn {
            isEnabled = true
            AccessibilityPermission.request()
        }
    }
}
