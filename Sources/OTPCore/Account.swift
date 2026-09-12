import Foundation

public enum OTPError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? {
        switch self { case .invalid(let text): return text }
    }
}

public enum Base32 {
    public static func decode(_ value: String) throws -> Data {
        let text = value.uppercased().filter { !$0.isWhitespace }
        let error = OTPError.invalid(L10n.text("Проверьте секретный ключ: нужны буквы A–Z и цифры 2–7 в формате Base32."))
        guard !text.isEmpty, text.count <= 4096 else { throw error }
        let unpadded = text.prefix { $0 != "=" }
        let suffix = text.dropFirst(unpadded.count)
        guard suffix.allSatisfy({ $0 == "=" }),
              [0, 2, 4, 5, 7].contains(unpadded.count % 8) else { throw error }
        if !suffix.isEmpty {
            guard text.count % 8 == 0, suffix.count == (8 - unpadded.count % 8) % 8 else { throw error }
        }
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567".utf8)
        var buffer: UInt32 = 0
        var bits = 0
        var output = Data()
        for character in unpadded.utf8 {
            guard let index = alphabet.firstIndex(of: character) else { throw error }
            buffer = (buffer << 5) | UInt32(index)
            bits += 5
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((buffer >> bits) & 255))
                buffer &= (1 << bits) - 1
            }
        }
        guard !output.isEmpty, buffer == 0 else { throw error }
        return output
    }
}

public struct OTPAccount: Codable, Identifiable, Equatable {
    public let id: UUID
    public let issuer: String
    public let name: String
    public let secret: Data
    public let algorithm: String
    public let digits: Int
    public let period: Int

    public var title: String { issuer.isEmpty ? name : issuer }
    public var subtitle: String { issuer.isEmpty ? "" : name }

    public init(id: UUID = UUID(), issuer: String, name: String, secret: Data,
                algorithm: String = "SHA1", digits: Int = 6, period: Int = 30) throws {
        let issuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 200, issuer.count <= 100 else {
            throw OTPError.invalid(L10n.text("Укажите название аккаунта (до 200 символов) и сервиса (до 100)."))
        }
        guard !secret.isEmpty, secret.count <= 2560 else { throw OTPError.invalid(L10n.text("Секретный ключ пустой или слишком длинный.")) }
        guard ["SHA1", "SHA256", "SHA512"].contains(algorithm.uppercased()) else {
            throw OTPError.invalid(L10n.text("Поддерживаются только SHA1, SHA256 и SHA512."))
        }
        guard [6, 8].contains(digits), (1...3600).contains(period) else {
            throw OTPError.invalid(L10n.text("Поддерживаются 6 или 8 цифр и период от 1 до 3600 секунд."))
        }
        self.id = id; self.issuer = issuer; self.name = name; self.secret = secret
        self.algorithm = algorithm.uppercased(); self.digits = digits; self.period = period
    }

    public func validated() throws -> OTPAccount {
        try OTPAccount(id: id, issuer: issuer, name: name, secret: secret, algorithm: algorithm, digits: digits, period: period)
    }

    public func code(at date: Date = Date()) throws -> String {
        try OTP.code(secret: secret, algorithm: algorithm, digits: digits, period: period, time: date.timeIntervalSince1970)
    }

    public static func parse(_ uri: String) throws -> OTPAccount {
        guard uri.count < 12000,
              let components = URLComponents(string: uri.trimmingCharacters(in: .whitespacesAndNewlines)),
              components.scheme?.lowercased() == "otpauth" else {
            throw OTPError.invalid(L10n.text("Нужна ссылка otpauth://totp/… из настройки двухфакторной аутентификации."))
        }
        guard components.host?.lowercased() == "totp" else {
            throw OTPError.invalid(L10n.text("Этот QR-код не является TOTP. HOTP и пакетный перенос Google пока не поддерживаются."))
        }
        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            let key = item.name.lowercased()
            guard values[key] == nil else { throw OTPError.invalid(L10n.text("В ссылке повторяются параметры. Получите новый QR-код у сервиса.")) }
            values[key] = item.value ?? ""
        }
        guard let secret = values["secret"] else { throw OTPError.invalid(L10n.text("В QR-коде отсутствует секретный ключ.")) }
        let label = String(components.path.drop(while: { $0 == "/" }))
        let parts = label.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let labelIssuer = parts.count == 2 ? String(parts[0]).trimmingCharacters(in: .whitespaces) : ""
        let name = parts.count == 2 ? String(parts[1]) : label
        let issuer = values["issuer"]?.trimmingCharacters(in: .whitespaces) ?? labelIssuer
        if !labelIssuer.isEmpty, !issuer.isEmpty, labelIssuer != issuer {
            throw OTPError.invalid(L10n.text("Названия сервиса в QR-коде не совпадают. Проверьте источник."))
        }
        guard let digits = Int(values["digits"] ?? "6"), let period = Int(values["period"] ?? "30") else {
            throw OTPError.invalid(L10n.text("Некорректное число цифр или период в QR-коде."))
        }
        return try OTPAccount(issuer: issuer, name: name, secret: Base32.decode(secret),
                              algorithm: values["algorithm"] ?? "SHA1", digits: digits, period: period)
    }
}
