import SwiftUI
import OTPCore

struct ManagementView: View {
    @ObservedObject var model: AppModel
    let recordShortcut: (Shortcut) -> Void
    let showPanel: () -> Void
    @State private var adding = false
    @State private var importing = false
    @State private var pendingImport: OTPAccount?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.text("Ваши коды. Под рукой.")).font(.system(size: 25, weight: .semibold))
                    Text(L10n.text("Вызовите панель, выберите аккаунт и нажмите Enter."))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "key.horizontal.fill").font(.system(size: 25)).foregroundStyle(.secondary)
            }
            if model.demo {
                Label(L10n.text("Деморежим · показаны тестовые аккаунты"), systemImage: "info.circle")
                    .font(.system(size: 12)).foregroundStyle(.orange)
            }
            HStack {
                Text(L10n.text("Аккаунты")).font(.system(size: 13, weight: .semibold))
                Text("\(model.accounts.count)").foregroundStyle(.secondary).font(.system(size: 12))
                Spacer()
                Button { importing = true; QRImport.choose { result in
                    importing = false
                    switch result {
                    case .success(let account): pendingImport = account
                    case .failure(let error): model.error = error.localizedDescription
                    }
                } } label: { Label(importing ? L10n.text("Читаем…") : L10n.text("QR из файла"), systemImage: "qrcode") }
                    .disabled(importing || model.demo || model.vaultUnavailable)
                Button { adding = true } label: { Label(L10n.text("Добавить"), systemImage: "plus") }
                    .disabled(importing || model.demo || model.vaultUnavailable)
            }
            accountList
            Divider()
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("Глобальное сочетание")).font(.system(size: 13, weight: .medium))
                    Text(L10n.text("Нажмите справа, затем введите новое сочетание."))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                ShortcutRecorder(label: model.shortcutLabel, onRecord: recordShortcut)
                    .frame(width: 170, height: 28)
                    .help(L10n.text("Используйте Control, Option или Command вместе с клавишей. Escape — отмена."))
            }
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.text("Язык")).font(.system(size: 13, weight: .medium))
                    Text(L10n.text("Применяется сразу, без перезапуска."))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Picker(L10n.text("Язык"), selection: $model.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }.id(model.language).labelsHidden().frame(width: 170)
            }
            HStack(spacing: 18) {
                hint("⇥ / ⇧⇥", L10n.text("Аккаунт"))
                hint(L10n.text("Текст"), L10n.text("Поиск"))
                hint("↵", L10n.text("Копировать"))
                hint("esc", L10n.text("Закрыть"))
                Spacer()
                Button(L10n.text("Показать панель"), action: showPanel)
            }
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                Text(L10n.text("Ключи хранятся в связке ключей этого Mac. Всё работает локально."))
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(26).frame(minWidth: 640, idealWidth: 660, minHeight: 610, idealHeight: 630)
        .sheet(isPresented: $adding) { AddAccountView(model: model) }
        .sheet(item: $pendingImport) { account in
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.text("Добавить аккаунт?")).font(.title2.weight(.semibold))
                Text(account.title).font(.headline)
                Text(account.name).foregroundStyle(.secondary)
                Text(L10n.text("%d цифр · %d сек · %@", account.digits, account.period, account.algorithm)).font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button(L10n.text("Отмена")) { pendingImport = nil }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button(L10n.text("Добавить")) {
                        do { try model.add(account); pendingImport = nil }
                        catch { pendingImport = nil; model.error = error.localizedDescription }
                    }.keyboardShortcut(.defaultAction)
                }
            }.padding(28).frame(width: 380)
        }
        .alert(L10n.text("Не удалось выполнить действие"), isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button(L10n.text("Понятно")) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private var accountList: some View {
        Group {
            if model.vaultUnavailable {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill").font(.title)
                    Text(L10n.text("Откройте доступ к связке ключей"))
                    Button(L10n.text("Повторить")) { model.reload() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.accounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder").font(.system(size: 32, weight: .light)).foregroundStyle(.secondary)
                    Text(L10n.text("Добавьте первый аккаунт")).font(.system(size: 15, weight: .medium))
                    Text(L10n.text("Выберите QR-код из настроек двухфакторной\nаутентификации или введите секретный ключ."))
                        .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.accounts) { account in
                            HStack(spacing: 12) {
                                Image(systemName: "key.horizontal").font(.system(size: 17)).foregroundStyle(.secondary).frame(width: 25)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(account.title).font(.system(size: 13, weight: .medium))
                                    Text(account.subtitle.isEmpty ? L10n.text("%d цифр · %d сек", account.digits, account.period) : account.subtitle)
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(L10n.text("Показать")) { model.selectedID = account.id; showPanel() }
                                Button { model.delete(account) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless).foregroundStyle(.secondary).disabled(model.demo)
                                    .help(L10n.text("Удалить аккаунт")).accessibilityLabel(L10n.text("Удалить %@", account.title))
                            }.padding(.horizontal, 14).padding(.vertical, 12)
                            if account.id != model.accounts.last?.id { Divider().padding(.leading, 51) }
                        }
                    }
                }
            }
        }
        .frame(height: 215)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.08)))
    }
    private func hint(_ key: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key).font(.system(size: 12, weight: .medium))
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }
    }
}

struct AddAccountView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var issuer = ""
    @State private var name = ""
    @State private var secret = ""
    @State private var uri = ""
    @State private var mode = 0
    @State private var algorithm = "SHA1"
    @State private var digits = 6
    @State private var period = "30"
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("Новый аккаунт")).font(.system(size: 22, weight: .semibold))
            Picker(L10n.text("Способ"), selection: $mode) {
                Text(L10n.text("Секретный ключ")).tag(0)
                Text(L10n.text("Ссылка otpauth")).tag(1)
            }.pickerStyle(.segmented)
            if mode == 0 {
                VStack(alignment: .leading, spacing: 12) {
                    field(L10n.text("Сервис")) { TextField(L10n.text("Например, GitHub"), text: $issuer) }
                    field(L10n.text("Аккаунт")) { TextField(L10n.text("Например, work или email"), text: $name) }
                    field(L10n.text("Секретный ключ Base32")) { SecureField(L10n.text("Ключ из настроек двухфакторной аутентификации"), text: $secret) }
                    DisclosureGroup(L10n.text("Дополнительные параметры")) {
                        HStack {
                            Picker(L10n.text("Алгоритм"), selection: $algorithm) {
                                Text("SHA1").tag("SHA1"); Text("SHA256").tag("SHA256"); Text("SHA512").tag("SHA512")
                            }
                            Picker(L10n.text("Цифры"), selection: $digits) { Text("6").tag(6); Text("8").tag(8) }.frame(width: 100)
                        }.padding(.top, 8)
                        HStack { Text(L10n.text("Период, секунд")); TextField("30", text: $period).frame(width: 70); Spacer() }.padding(.top, 4)
                    }.font(.system(size: 12))
                }
            } else {
                field(L10n.text("Ссылка из настроек сервиса")) { SecureField("otpauth://totp/…", text: $uri) }
            }
            if let error { Text(error).font(.system(size: 12)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            Text(L10n.text("Ключ останется в связке ключей этого Mac.")).font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button(L10n.text("Отмена")) { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button(L10n.text("Добавить")) { save() }.keyboardShortcut(.defaultAction)
                    .disabled(mode == 0 ? name.trimmingCharacters(in: .whitespaces).isEmpty || secret.isEmpty : uri.isEmpty)
            }
        }.padding(28).frame(width: 440)
    }
    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .medium))
            content().textFieldStyle(.roundedBorder)
        }
    }
    private func save() {
        do {
            let account: OTPAccount
            if mode == 1 { account = try OTPAccount.parse(uri) }
            else {
                guard let period = Int(period) else { throw OTPError.invalid(L10n.text("Период должен быть целым числом секунд.")) }
                account = try OTPAccount(issuer: issuer, name: name, secret: Base32.decode(secret), algorithm: algorithm, digits: digits, period: period)
            }
            try model.add(account)
            secret = ""; uri = ""; dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
