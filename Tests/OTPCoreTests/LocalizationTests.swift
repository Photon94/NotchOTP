import XCTest
@testable import OTPCore

final class LocalizationTests: XCTestCase {
    func testSystemLanguageResolutionAndFallback() {
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["ru-RU", "en-US"]), .russian)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["de-DE", "en-GB", "ru"]), .german)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: []), .english)
        XCTAssertEqual(AppLanguage.english.resolved(preferredLanguages: ["ru"]), .english)
    }

    func testNewLanguageResolution() {
        let cases: [(String, AppLanguage)] = [
            ("zh-Hans-CN", .chinese), ("zh_CN", .chinese), ("zh-SG", .chinese),
            ("de-AT", .german), ("fr-CA", .french), ("hi-IN", .hindi)
        ]
        for (identifier, expected) in cases {
            XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: [identifier, "en"]), expected)
        }
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["ja-JP", "fr-FR"]), .french)
        XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: ["ja-JP"]), .english)
        for traditional in ["zh-Hant-TW", "zh-TW", "zh-HK", "zh-MO"] {
            XCTAssertEqual(AppLanguage.system.resolved(preferredLanguages: [traditional, "en-US"]), .english)
        }
    }

    func testAllCatalogsAreCompleteAndPreserveFormatArguments() {
        let expression = try! NSRegularExpression(pattern: "%[@d]")
        func formats(_ value: String) -> [String] {
            expression.matches(in: value, range: NSRange(value.startIndex..., in: value)).map {
                String(value[Range($0.range, in: value)!])
            }
        }
        for language in AppLanguage.allCases where language != .system && language != .russian {
            let catalog = L10n.catalog(for: language)
            XCTAssertEqual(Set(catalog.keys), Set(L10n.english.keys), "Missing keys: \(language)")
            for (key, value) in catalog {
                XCTAssertFalse(value.isEmpty)
                XCTAssertEqual(formats(key), formats(value), "Wrong placeholders: \(language) \(key)")
            }
        }
    }

    func testNewLanguageTranslationsPreserveAccountNamesAndCodeDigits() {
        let previous = L10n.language
        defer { L10n.language = previous }
        let cases: [(AppLanguage, String)] = [(.chinese, "添加"), (.german, "Hinzufügen"), (.french, "Ajouter"), (.hindi, "जोड़ें")]
        for (language, add) in cases {
            L10n.language = language
            XCTAssertEqual(L10n.text("Добавить"), add)
            XCTAssertTrue(L10n.text("Удалить %@?", "Мой GitHub 日本").contains("Мой GitHub 日本"))
        }
        let account = try! OTPAccount(issuer: "Example", name: "मेरा खाता", secret: Data("12345678901234567890".utf8))
        let code = try! account.code(at: Date(timeIntervalSince1970: 59))
        XCTAssertEqual(code, "287082")
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
