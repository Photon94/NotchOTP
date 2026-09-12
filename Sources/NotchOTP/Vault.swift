import Foundation
import Security
import OTPCore

struct KeychainVault {
    let service: String
    init(service: String = "local.photon.NotchOTP.vault.v1") { self.service = service }
    private let account = "accounts"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    func load() throws -> [OTPAccount] {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw failure(status) }
        guard let data = result as? Data else { throw OTPError.invalid(L10n.text("Не удалось прочитать хранилище. Данные не изменены.")) }
        do {
            let accounts = try JSONDecoder().decode([OTPAccount].self, from: data).map { try $0.validated() }
            guard Set(accounts.map(\.id)).count == accounts.count else { throw OTPError.invalid("Duplicate IDs") }
            return accounts
        } catch {
            throw OTPError.invalid(L10n.text("Хранилище содержит повреждённые данные. Оно не будет перезаписано."))
        }
    }

    func save(_ accounts: [OTPAccount]) throws {
        let data = try JSONEncoder().encode(accounts)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrLabel as String] = L10n.text("NotchOTP — аккаунты двухфакторной аутентификации")
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let added = SecItemAdd(item as CFDictionary, nil)
            guard added == errSecSuccess else { throw failure(added) }
        } else if status != errSecSuccess { throw failure(status) }
    }

    private func failure(_ status: OSStatus) -> OTPError {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? L10n.text("Ошибка %d", status)
        return .invalid(L10n.text("Связка ключей недоступна: %@. Разблокируйте её и попробуйте снова.", message))
    }
}
