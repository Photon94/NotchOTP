import XCTest
import CoreImage
import Security
import OTPCore
@testable import NotchOTP

final class IntegrationTests: XCTestCase {
    func testQRImageRoundTrip() throws {
        let filter = try XCTUnwrap(CIFilter(name: "CIQRCodeGenerator"))
        filter.setValue(Data("otpauth://totp/Test:fixture?secret=JBSWY3DPEHPK3PXP&issuer=Test".utf8), forKey: "inputMessage")
        let image = try XCTUnwrap(filter.outputImage).transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let cg = try XCTUnwrap(CIContext().createCGImage(image, from: image.extent))
        let account = try QRImport.decode(cg)
        XCTAssertEqual(account.issuer, "Test")
        XCTAssertEqual(account.name, "fixture")
        XCTAssertEqual(account.secret, Data([72,101,108,108,111,33,222,173,190,239]))
    }
    func testKeychainPersistsUpdatesAndRejectsCorruption() throws {
        guard ProcessInfo.processInfo.environment["NOTCHOTP_KEYCHAIN_TESTS"] == "1" else {
            throw XCTSkip("Run opt-in integration with NOTCHOTP_KEYCHAIN_TESTS=1")
        }
        let service = "local.photon.NotchOTP.tests." + UUID().uuidString
        let vault = KeychainVault(service: service)
        let query = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service] as [String: Any]
        defer { SecItemDelete(query as CFDictionary) }
        XCTAssertTrue(try vault.load().isEmpty)
        let first = try OTPAccount(issuer: "RFC test", name: "disposable fixture", secret: Data("12345678901234567890".utf8))
        try vault.save([first])
        XCTAssertEqual(try KeychainVault(service: service).load(), [first])
        try vault.save([])
        XCTAssertTrue(try vault.load().isEmpty)
        XCTAssertEqual(SecItemUpdate(query as CFDictionary, [kSecValueData as String: Data("corrupt test fixture".utf8)] as CFDictionary), errSecSuccess)
        XCTAssertThrowsError(try vault.load())
    }
}
