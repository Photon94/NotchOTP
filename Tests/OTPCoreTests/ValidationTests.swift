import XCTest
@testable import OTPCore

final class ValidationTests: XCTestCase {
    func testBase32KnownEncodingAndFormatting() throws {
        XCTAssertEqual(try Base32.decode("MZXW6YTBOI======"), Data("foobar".utf8))
        XCTAssertEqual(try Base32.decode("mzxw 6ytb oi"), Data("foobar".utf8))
        XCTAssertEqual(try Base32.decode("MY======"), Data("f".utf8))
    }
    func testBase32RejectsMalformedAndAmbiguousInput() {
        for value in ["", "A", "M1", "M0", "MZ", "MY=AAA", "MY=====", "😀"] {
            XCTAssertThrowsError(try Base32.decode(value), value)
        }
    }
    func testURIParsesParametersAndUnicode() throws {
        let account = try OTPAccount.parse("otpauth://totp/GitHub:work%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=GitHub&algorithm=SHA256&digits=8&period=60")
        XCTAssertEqual(account.issuer, "GitHub")
        XCTAssertEqual(account.name, "work@example.com")
        XCTAssertEqual(account.algorithm, "SHA256")
        XCTAssertEqual(account.digits, 8)
        XCTAssertEqual(account.period, 60)
        XCTAssertEqual(account.secret, Data([72,101,108,108,111,33,222,173,190,239]))
    }
    func testURIRejectsUnsupportedOrConflictingParameters() {
        for uri in [
            "otpauth://hotp/Test?secret=JBSWY3DPEHPK3PXP&counter=1",
            "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&algorithm=MD5",
            "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&period=0",
            "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&digits=7",
            "otpauth://totp/Test?secret=JBSWY3DPEHPK3PXP&secret=MY",
            "otpauth://totp/One:work?secret=JBSWY3DPEHPK3PXP&issuer=Two",
            "https://example.com", "otpauth://totp/Test"
        ] { XCTAssertThrowsError(try OTPAccount.parse(uri), uri) }
    }
    func testInvalidGeneratorInputsCannotCrashOrSilentlyGenerate() {
        XCTAssertThrowsError(try OTP.code(secret: Data(), time: 59))
        XCTAssertThrowsError(try OTP.code(secret: Data([1]), digits: 0, time: 59))
        XCTAssertThrowsError(try OTP.code(secret: Data([1]), period: 0, time: 59))
        XCTAssertThrowsError(try OTP.code(secret: Data([1]), time: -1))
        XCTAssertThrowsError(try OTP.code(secret: Data([1]), time: .infinity))
    }
    func testSixDigitCodeAndPeriodBoundary() throws {
        let secret = Data("12345678901234567890".utf8)
        XCTAssertEqual(try OTP.code(secret: secret, digits: 6, time: 59.999), "287082")
        XCTAssertEqual(try OTP.code(secret: secret, digits: 6, time: 60), "359152")
        XCTAssertEqual(try OTP.code(secret: secret, digits: 6, period: 60, time: 119), "287082")
    }
}
