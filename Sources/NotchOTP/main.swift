import OTPCore
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var model: AppModel!
    private var overlay: PanelController!
    private var manager: NSWindow?
    private let hotkey = GlobalHotKey()
    private var shortcut = Shortcut.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let demo = CommandLine.arguments.contains("--demo")
        model = AppModel(demo: demo)
        overlay = PanelController(model: model)
        model.showManagement = { [weak self] in self?.openManagement() }
        if let data = UserDefaults.standard.data(forKey: "shortcut"), let saved = try? JSONDecoder().decode(Shortcut.self, from: data) { shortcut = saved }
        hotkey.action = { [weak self] in self?.overlay.toggle() }
        if !hotkey.register(shortcut) { model.error = L10n.text("Не удалось зарегистрировать сочетание. Выберите другое в настройках; панель доступна через значок ключа в строке меню.") }
        model.shortcutLabel = shortcut.label
        model.languageChanged = { [weak self] in self?.buildMenu() }
        buildMenu()
        if demo { overlay.show() }
        else if model.accounts.isEmpty || model.vaultUnavailable || model.error != nil { openManagement() }
    }

    private func buildMenu() {
        if statusItem == nil { statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength) }
        statusItem.button?.image = NSImage(systemSymbolName: "key.horizontal", accessibilityDescription: "NotchOTP")
        statusItem.button?.toolTip = "NotchOTP — \(shortcut.label)"
        let menu = NSMenu()
        let show = NSMenuItem(title: L10n.text("Показать код   %@", shortcut.label), action: #selector(togglePanel), keyEquivalent: "")
        show.target = self; menu.addItem(show)
        let accounts = NSMenuItem(title: L10n.text("Аккаунты и настройки…"), action: #selector(openManagement), keyEquivalent: ",")
        accounts.target = self; menu.addItem(accounts)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: L10n.text("Завершить NotchOTP"), action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        statusItem.menu = menu

        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appSubmenu = NSMenu()
        appSubmenu.addItem(withTitle: L10n.text("Завершить NotchOTP"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appSubmenu; appMenu.addItem(appMenuItem)
        let edit = NSMenuItem(title: L10n.text("Правка"), action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: L10n.text("Правка"))
        editMenu.addItem(withTitle: L10n.text("Отменить"), action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: L10n.text("Вырезать"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: L10n.text("Копировать"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: L10n.text("Вставить"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: L10n.text("Выбрать всё"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        edit.submenu = editMenu; appMenu.addItem(edit)
        NSApp.mainMenu = appMenu
    }

    @objc private func togglePanel() { overlay.toggle() }
    @objc private func openManagement() {
        overlay.hide(restoreFocus: false)
        if manager == nil {
            let view = ManagementView(model: model, recordShortcut: { [weak self] in self?.updateShortcut($0) }, showPanel: { [weak self] in self?.overlay.show() })
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 660, height: 630), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
            window.title = "NotchOTP"
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: view)
            window.center()
            manager = window
        }
        NSApp.activate(ignoringOtherApps: true)
        manager?.makeKeyAndOrderFront(nil)
    }
    private func updateShortcut(_ value: Shortcut) {
        if value.keyCode == shortcut.keyCode && value.modifiers == shortcut.modifiers { return }
        guard hotkey.register(value) else {
            model.error = L10n.text("Это сочетание занято. Попробуйте другое; прежнее сочетание продолжает работать.")
            return
        }
        shortcut = value
        model.shortcutLabel = value.label
        if !model.demo { UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: "shortcut") }
        statusItem.button?.toolTip = "NotchOTP — \(value.label)"
        statusItem.menu?.items.first?.title = L10n.text("Показать код   %@", value.label)
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { openManagement(); return true }
    func applicationWillTerminate(_ notification: Notification) { model.clearClipboardIfOwned() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
