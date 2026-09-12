import Foundation
import CryptoKit

public enum OTP {
    public static func code(secret: Data, algorithm: String = "SHA1", digits: Int = 8,
                            period: Int = 30, time: TimeInterval) throws -> String {
        guard !secret.isEmpty, [6, 8].contains(digits), (1...3600).contains(period),
              time.isFinite, time >= 0, time < Double(UInt64.max) else {
            throw OTPError.invalid(L10n.text("Некорректные параметры кода или системное время."))
        }
        var counter = UInt64(floor(time / Double(period))).bigEndian
        let message = withUnsafeBytes(of: &counter) { Data($0) }
        let key = SymmetricKey(data: secret)
        let hash: [UInt8]
        switch algorithm.uppercased() {
        case "SHA1": hash = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case "SHA256": hash = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case "SHA512": hash = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
        default: throw OTPError.invalid(L10n.text("Этот алгоритм не поддерживается. Используйте SHA1, SHA256 или SHA512."))
        }
        let offset = Int(hash[hash.count - 1] & 0x0f)
        let binary = (UInt32(hash[offset] & 0x7f) << 24)
            | (UInt32(hash[offset + 1]) << 16)
            | (UInt32(hash[offset + 2]) << 8) | UInt32(hash[offset + 3])
        let modulus: UInt32 = digits == 6 ? 1_000_000 : 100_000_000
        return String(format: "%0*u", digits, binary % modulus)
    }

    public static func remaining(period: Int, time: TimeInterval) -> Double {
        guard period > 0, time.isFinite, time >= 0 else { return 0 }
        return Double(period) - time.truncatingRemainder(dividingBy: Double(period))
    }

    public static func formatted(_ code: String) -> String {
        let middle = code.index(code.startIndex, offsetBy: code.count / 2)
        return String(code[..<middle]) + " " + String(code[middle...])
    }
}
