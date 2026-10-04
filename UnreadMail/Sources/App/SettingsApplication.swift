import AppKit
import SwiftUI

@MainActor
final class SettingsAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var receivedURL = false
    private var pendingOpens = 0
    private lazy var model = MailModel()

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(receiveURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        // URL events are delivered during launch. Defer normal startup so a widget
        // click can be routed without constructing a settings window or Dock icon.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.receivedURL else { return }
            self.showSettings()
        }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }
    @objc private func receiveURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        guard let raw = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: raw) else { return }
        receivedURL = true
        let destination = MailLink.destination(for: url, snapshot: SnapshotStore.load())
        switch destination {
        case .settings: showSettings()
        case .inbox: openMail(messageURL: nil)
        case .message(let messageURL): openMail(messageURL: messageURL)
        }
    }
    private func openMail(messageURL: URL?) {
        guard let mail = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.mail") else {
            finishOpen()
            return
        }
        pendingOpens += 1
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        let completion: @Sendable (NSRunningApplication?, Error?) -> Void = { [weak self] _, _ in
            Task { @MainActor in self?.finishOpen() }
        }
        if let messageURL {
            NSWorkspace.shared.open([messageURL], withApplicationAt: mail, configuration: configuration, completionHandler: completion)
        } else {
            NSWorkspace.shared.openApplication(at: mail, configuration: configuration, completionHandler: completion)
        }
    }
    private func finishOpen() {
        pendingOpens = max(0, pendingOpens - 1)
        if window == nil && pendingOpens == 0 { NSApp.terminate(nil) }
    }
    private func showSettings() {
        NSApp.setActivationPolicy(.regular)
        if window == nil {
            let controller = NSHostingController(rootView: ContentView(model: model))
            let newWindow = NSWindow(contentViewController: controller)
            newWindow.title = "Mail Widgets"
            newWindow.styleMask = [.titled, .closable, .miniaturizable]
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            window = newWindow
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
enum SettingsApplication {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = SettingsAppDelegate()
        app.delegate = delegate
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Mail Widgets")
        appMenu.addItem(withTitle: "Quit Mail Widgets", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)
        app.mainMenu = menu
        withExtendedLifetime(delegate) { app.run() }
    }
}
