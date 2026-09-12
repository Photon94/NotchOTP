import AppKit
import Combine
import OTPCore

final class AppModel: ObservableObject {
    @Published private(set) var accounts: [OTPAccount] = []
    @Published var selectedID: UUID?
    @Published var query = ""
    @Published var searching = false
    @Published var panelVisible = false
    @Published var panelRevealed = false
    @Published var copied = false
    @Published var error: String?
    @Published var vaultUnavailable = false
    @Published var shortcutLabel = "⌃⌥Space"
    @Published var language = L10n.language {
        didSet {
            L10n.language = language
            if !demo { UserDefaults.standard.set(language.rawValue, forKey: "appLanguage") }
            languageChanged?()
            layoutChanged?()
        }
    }
    var languageChanged: (() -> Void)?
    let demo: Bool
    var layoutChanged: (() -> Void)?
    var hidePanel: (() -> Void)?
    var showManagement: (() -> Void)?
    private let vault = KeychainVault()
    private var clipboardTimer: Timer?
    private var clipboardChange: Int?
    private var copyGeneration = 0

    init(demo: Bool) {
        self.demo = demo
        if demo {
            // Public RFC fixture only. Demo does not access Keychain.
            accounts = [
                try! OTPAccount(issuer: "GitHub", name: "work · demo", secret: Data("12345678901234567890".utf8)),
                try! OTPAccount(issuer: "Google", name: "personal · demo", secret: Data("12345678901234567890123456789012".utf8), algorithm: "SHA256"),
                try! OTPAccount(issuer: "AWS", name: "cloud · demo", secret: Data("12345678901234567890".utf8))
            ]
            selectedID = accounts.first?.id
        } else { reload() }
    }

    var filtered: [OTPAccount] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return accounts.filter { account in
            terms.allSatisfy { "\(account.issuer) \(account.name)".localizedStandardContains($0) }
        }
    }
    var selected: OTPAccount? { filtered.first(where: { $0.id == selectedID }) ?? filtered.first }

    func reload() {
        guard !demo else { return }
        do {
            accounts = try vault.load()
            selectedID = accounts.first?.id
            vaultUnavailable = false
            error = nil
        } catch { vaultUnavailable = true; self.error = error.localizedDescription }
    }

    func add(_ account: OTPAccount) throws {
        guard !demo else { throw OTPError.invalid(L10n.text("Это деморежим. Перезапустите приложение, чтобы добавить свой аккаунт.")) }
        guard !vaultUnavailable else { throw OTPError.invalid(L10n.text("Сначала откройте доступ к связке ключей.")) }
        guard !accounts.contains(where: { $0.secret == account.secret && $0.issuer == account.issuer && $0.name == account.name }) else {
            throw OTPError.invalid(L10n.text("Этот аккаунт уже добавлен."))
        }
        let next = accounts + [account]
        try vault.save(next)
        accounts = next
        selectedID = account.id
        layoutChanged?()
    }

    func delete(_ account: OTPAccount) {
        guard !demo, !vaultUnavailable else { return }
        let alert = NSAlert()
        alert.messageText = L10n.text("Удалить %@?", account.title)
        alert.informativeText = L10n.text("Ключ исчезнет из NotchOTP. Убедитесь, что у вас есть другой способ входа в этот аккаунт.")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.text("Отмена"))
        alert.addButton(withTitle: L10n.text("Удалить"))
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do {
            let next = accounts.filter { $0.id != account.id }
            try vault.save(next)
            accounts = next
            if selectedID == account.id { selectedID = next.first?.id }
            layoutChanged?()
        } catch { self.error = error.localizedDescription }
    }

    func beginSearch() { searching = true; layoutChanged?() }
    func setQuery(_ value: String) {
        query = String(value.prefix(200))
        searching = true
        selectedID = filtered.first?.id
        layoutChanged?()
    }
    func cycle(_ delta: Int) {
        let matches = filtered
        guard !matches.isEmpty else { return }
        let index = matches.firstIndex(where: { $0.id == selectedID }) ?? 0
        selectedID = matches[(index + delta + matches.count) % matches.count].id
        copied = false
    }
    func resetPanel() {
        query = ""; searching = false; copied = false
        copyGeneration += 1
    }

    func copySelected() {
        guard let account = selected else { return }
        do {
            let now = Date()
            let code = try account.code(at: now)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            let item = NSPasteboardItem()
            item.setString(code, forType: .string)
            item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
            item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
            item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.localOnly"))
            guard pasteboard.writeObjects([item]) else { throw OTPError.invalid(L10n.text("Не удалось скопировать код. Попробуйте ещё раз.")) }
            clipboardTimer?.invalidate()
            clipboardChange = pasteboard.changeCount
            clipboardTimer = Timer.scheduledTimer(withTimeInterval: min(30, OTP.remaining(period: account.period, time: now.timeIntervalSince1970)), repeats: false) { [weak self] _ in self?.clearClipboardIfOwned() }
            copied = true
            copyGeneration += 1
            let generation = copyGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                guard let self, self.copyGeneration == generation else { return }
                self.hidePanel?()
            }
        } catch { self.error = error.localizedDescription; showManagement?() }
    }

    func clearClipboardIfOwned() {
        if let change = clipboardChange, NSPasteboard.general.changeCount == change {
            NSPasteboard.general.clearContents()
        }
        clipboardChange = nil
    }
}
