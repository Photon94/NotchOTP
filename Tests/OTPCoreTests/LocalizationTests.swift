import XCTest
@testable import OTPCore

final class LocalizationTests: XCTestCase {
    func testSystemLanguageResolutionAndFallback() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["ru-RU", "en-US"]), .russian)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["de-DE", "en-GB", "ru"]), .english)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: []), .english)
        XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages: ["ru"]), .english)
    }

    func testTranslationsAndUserContent() {
        let previous = L10n.language
        defer { L10n.language = previous }
        L10n.language = .english
        XCTAssertEqual(L10n.text("Добавить"), "Add")
        XCTAssertEqual(L10n.text("Удалить %@?", "Мой GitHub"), "Delete Мой GitHub?")
        XCTAssertEqual(L10n.text("%d цифр · %d сек", 6, 30), "6 digits · 30 sec")
        L10n.language = .russian
        XCTAssertEqual(L10n.text("Добавить"), "Добавить")
        XCTAssertEqual(L10n.text("Удалить %@?", "My GitHub"), "Удалить My GitHub?")
    }

    func testParserErrorsUseSelectedLanguage() {
        let previous = L10n.language
        defer { L10n.language = previous }
        L10n.language = .english
        XCTAssertThrowsError(try Base32.decode("!")) {
            XCTAssertTrue($0.localizedDescription.hasPrefix("Check the secret key"))
        }
        L10n.language = .russian
        XCTAssertThrowsError(try Base32.decode("!")) {
            XCTAssertTrue($0.localizedDescription.hasPrefix("Проверьте секретный ключ"))
        }
    }
}
