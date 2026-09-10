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
                    Text("Ваши коды. Под рукой.").font(.system(size: 25, weight: .semibold))
                    Text("Вызовите панель, выберите аккаунт и нажмите Enter.")
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "key.horizontal.fill").font(.system(size: 25)).foregroundStyle(.secondary)
            }
            if model.demo {
                Label("Деморежим · показаны тестовые аккаунты", systemImage: "info.circle")
                    .font(.system(size: 12)).foregroundStyle(.orange)
            }
            HStack {
                Text("Аккаунты").font(.system(size: 13, weight: .semibold))
                Text("\(model.accounts.count)").foregroundStyle(.secondary).font(.system(size: 12))
                Spacer()
                Button { importing = true; QRImport.choose { result in
                    importing = false
                    switch result {
                    case .success(let account): pendingImport = account
                    case .failure(let error): model.error = error.localizedDescription
                    }
                } } label: { Label(importing ? "Читаем…" : "QR из файла", systemImage: "qrcode") }
                    .disabled(importing || model.demo || model.vaultUnavailable)
                Button { adding = true } label: { Label("Добавить", systemImage: "plus") }
                    .disabled(importing || model.demo || model.vaultUnavailable)
            }
            accountList
            Divider()
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Глобальное сочетание").font(.system(size: 13, weight: .medium))
                    Text("Нажмите справа, затем введите новое сочетание.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                ShortcutRecorder(label: model.shortcutLabel, onRecord: recordShortcut)
                    .frame(width: 170, height: 28)
                    .help("Используйте Control, Option или Command вместе с клавишей. Escape — отмена.")
            }
            HStack(spacing: 18) {
                hint("⇥ / ⇧⇥", "Аккаунт")
                hint("Текст", "Поиск")
                hint("↵", "Копировать")
                hint("esc", "Закрыть")
                Spacer()
                Button("Показать панель", action: showPanel)
            }
            Spacer(minLength: 0)
            HStack(spacing: 7) {
                Image(systemName: "lock.shield")
                Text("Ключи хранятся в связке ключей этого Mac. Всё работает локально.")
            }.font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(26).frame(minWidth: 640, idealWidth: 660, minHeight: 540, idealHeight: 560)
        .sheet(isPresented: $adding) { AddAccountView(model: model) }
        .sheet(item: $pendingImport) { account in
            VStack(alignment: .leading, spacing: 18) {
                Text("Добавить аккаунт?").font(.title2.weight(.semibold))
                Text(account.title).font(.headline)
                Text(account.name).foregroundStyle(.secondary)
                Text("\(account.digits) цифр · \(account.period) сек · \(account.algorithm)").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Отмена") { pendingImport = nil }.keyboardShortcut(.cancelAction)
                    Spacer()
                    Button("Добавить") {
                        do { try model.add(account); pendingImport = nil }
                        catch { pendingImport = nil; model.error = error.localizedDescription }
                    }.keyboardShortcut(.defaultAction)
                }
            }.padding(28).frame(width: 380)
        }
        .alert("Не удалось выполнить действие", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("Понятно") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private var accountList: some View {
        Group {
            if model.vaultUnavailable {
                VStack(spacing: 12) {
                    Image(systemName: "lock.fill").font(.title)
                    Text("Откройте доступ к связке ключей")
                    Button("Повторить") { model.reload() }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.accounts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "qrcode.viewfinder").font(.system(size: 32, weight: .light)).foregroundStyle(.secondary)
                    Text("Добавьте первый аккаунт").font(.system(size: 15, weight: .medium))
                    Text("Выберите QR-код из настроек двухфакторной\nаутентификации или введите секретный ключ.")
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
                                    Text(account.subtitle.isEmpty ? "\(account.digits) цифр · \(account.period) сек" : account.subtitle)
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Показать") { model.selectedID = account.id; showPanel() }
                                Button { model.delete(account) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless).foregroundStyle(.secondary).disabled(model.demo)
                                    .help("Удалить аккаунт").accessibilityLabel("Удалить \(account.title)")
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
            Text("Новый аккаунт").font(.system(size: 22, weight: .semibold))
            Picker("Способ", selection: $mode) {
                Text("Секретный ключ").tag(0)
                Text("Ссылка otpauth").tag(1)
            }.pickerStyle(.segmented)
            if mode == 0 {
                VStack(alignment: .leading, spacing: 12) {
                    field("Сервис") { TextField("Например, GitHub", text: $issuer) }
                    field("Аккаунт") { TextField("Например, work или email", text: $name) }
                    field("Секретный ключ Base32") { SecureField("Ключ из настроек двухфакторной аутентификации", text: $secret) }
                    DisclosureGroup("Дополнительные параметры") {
                        HStack {
                            Picker("Алгоритм", selection: $algorithm) {
                                Text("SHA1").tag("SHA1"); Text("SHA256").tag("SHA256"); Text("SHA512").tag("SHA512")
                            }
                            Picker("Цифры", selection: $digits) { Text("6").tag(6); Text("8").tag(8) }.frame(width: 100)
                        }.padding(.top, 8)
                        HStack { Text("Период, секунд"); TextField("30", text: $period).frame(width: 70); Spacer() }.padding(.top, 4)
                    }.font(.system(size: 12))
                }
            } else {
                field("Ссылка из настроек сервиса") { SecureField("otpauth://totp/…", text: $uri) }
            }
            if let error { Text(error).font(.system(size: 12)).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
            Text("Ключ останется в связке ключей этого Mac.").font(.system(size: 11)).foregroundStyle(.secondary)
            HStack {
                Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Добавить") { save() }.keyboardShortcut(.defaultAction)
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
                guard let period = Int(period) else { throw OTPError.invalid("Период должен быть целым числом секунд.") }
                account = try OTPAccount(issuer: issuer, name: name, secret: Base32.decode(secret), algorithm: algorithm, digits: digits, period: period)
            }
            try model.add(account)
            secret = ""; uri = ""; dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
