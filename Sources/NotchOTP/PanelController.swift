import AppKit
import SwiftUI

final class OTPPanel: NSPanel {
    var keyAction: ((NSEvent) -> Bool)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func keyDown(with event: NSEvent) {
        if keyAction?(event) != true { super.keyDown(with: event) }
    }
    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, keyAction?(event) == true { return }
        super.sendEvent(event)
    }
}

final class PanelController: NSObject, NSWindowDelegate {
    let model: AppModel
    let panel: OTPPanel
    private var previousApp: NSRunningApplication?
    private var screen: NSScreen?
    private var globalClick: Any?
    private var localClick: Any?
    private var hostingView: NSHostingView<PanelView>?
    private var visibilityGeneration = 0
    private var closing = false

    init(model: AppModel) {
        self.model = model
        panel = OTPPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.delegate = self
        panel.keyAction = { [weak self] in self?.handle($0) ?? false }
        model.layoutChanged = { [weak self] in self?.layout() }
        model.hidePanel = { [weak self] in self?.hide() }
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleeping), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(sleeping), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
    }

    func toggle() { panel.isVisible && !closing ? hide() : show() }
    func show() {
        guard !panel.isVisible || closing else { return }
        visibilityGeneration += 1
        let generation = visibilityGeneration
        closing = false
        panel.ignoresMouseEvents = false
        model.panelRevealed = false
        previousApp = NSWorkspace.shared.frontmostApplication
        let cursor = NSEvent.mouseLocation
        screen = NSScreen.screens.first { $0.frame.contains(cursor) } ?? NSScreen.main ?? NSScreen.screens.first
        model.resetPanel()
        model.panelVisible = true
        layout()
        hostingView?.layoutSubtreeIfNeeded()
        panel.makeKeyAndOrderFront(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.016) { [weak self] in
            guard let self, self.visibilityGeneration == generation, !self.closing else { return }
            self.model.panelRevealed = true
        }
        globalClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.hide(restoreFocus: false) }
        localClick = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            if let self, event.window !== self.panel { self.hide(restoreFocus: false) }
            return event
        }
    }
    func hide(restoreFocus: Bool = true, animated: Bool = true) {
        guard panel.isVisible, !closing || !animated else { return }
        closing = true
        visibilityGeneration += 1
        let generation = visibilityGeneration
        model.panelRevealed = false
        panel.ignoresMouseEvents = true
        let delay = !animated || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.0 : 0.18
        let finish: () -> Void = { [weak self] in
            guard let self, self.visibilityGeneration == generation else { return }
            self.model.panelVisible = false
            self.panel.orderOut(nil)
            self.closing = false
        }
        if delay == 0 { finish() }
        else { DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: finish) }
        if let globalClick { NSEvent.removeMonitor(globalClick); self.globalClick = nil }
        if let localClick { NSEvent.removeMonitor(localClick); self.localClick = nil }
        if restoreFocus, let previousApp, previousApp.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            previousApp.activate(options: [])
        }
        previousApp = nil
    }

    func layout() {
        guard let screen = screen ?? NSScreen.main else { return }
        let safeTop = screen.safeAreaInsets.top
        let left = screen.auxiliaryTopLeftArea
        let right = screen.auxiliaryTopRightArea
        let neckWidth: CGFloat = safeTop > 0 ? max(160, (right?.minX ?? screen.frame.midX + 90) - (left?.maxX ?? screen.frame.midX - 90)) : 0
        let width: CGFloat = safeTop > 0 ? neckWidth : 260
        let visibleRows = CGFloat(min(5, model.filtered.count))
        let rowsHeight: CGFloat = visibleRows * 65 - 3
        let searchChromeHeight: CGFloat = 84
        var contentHeight: CGFloat = 86
        if model.searching && !model.accounts.isEmpty {
            contentHeight = max(50, rowsHeight) + searchChromeHeight
        }
        let height = safeTop + contentHeight
        let top = safeTop > 0 ? screen.frame.maxY : screen.visibleFrame.maxY - 4
        let center = safeTop > 0 && left != nil && right != nil ? ((left!.maxX + right!.minX) / 2) : screen.frame.midX
        panel.setFrame(NSRect(x: center - width / 2, y: top - height, width: width, height: height), display: true)
        let root = PanelView(model: model, neckHeight: safeTop, width: width, height: height)
        if let hostingView { hostingView.rootView = root }
        else {
            let hosting = NSHostingView(rootView: root)
            hostingView = hosting
            panel.contentView = hosting
        }
    }

    private func handle(_ event: NSEvent) -> Bool {
        guard !closing else { return true }
        let command = event.modifierFlags.contains(.command)
        switch event.keyCode {
        case 53: hide(); return true
        case 36, 76:
            if model.accounts.isEmpty || model.vaultUnavailable { model.showManagement?() }
            else { model.copySelected() }
            return true
        case 48: model.cycle(event.modifierFlags.contains(.shift) ? -1 : 1); return true
        case 125: model.cycle(1); return true
        case 126: model.cycle(-1); return true
        case 51:
            if model.searching { model.setQuery(String(model.query.dropLast())) }
            return true
        default: break
        }
        if command {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "c": model.copySelected(); return true
            case "v":
                if let text = NSPasteboard.general.string(forType: .string) { model.setQuery(model.query + text) }
                return true
            case "f": model.beginSearch(); return true
            case "a": model.setQuery(""); return true
            case ",": model.showManagement?(); return true
            default: return false
            }
        }
        guard !event.modifierFlags.contains(.control), !event.modifierFlags.contains(.option),
              let text = event.characters, !text.isEmpty,
              text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && ($0.value < 0xF700 || $0.value > 0xF8FF) }) else { return false }
        model.setQuery(model.query + text)
        return true
    }
    func windowDidResignKey(_ notification: Notification) { hide(restoreFocus: false) }
    @objc private func screenChanged() {
        if panel.isVisible {
            screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
            layout()
        }
    }
    @objc private func sleeping() { hide(restoreFocus: false, animated: false); model.clearClipboardIfOwned() }
}
