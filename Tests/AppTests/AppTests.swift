import XCTest
import AppKit
import CoreImage
import Security
import OTPCore
@testable import NotchOTP

final class AppTests: XCTestCase {
    func testDemoLanguageSwitchUpdatesUIWithoutPersistingOrChangingAccounts() {
        let previous = L10n.language
        defer { L10n.language = previous }
        let preference = UserDefaults.standard.string(forKey: "appLanguage")
        let model = AppModel(demo: true)
        let original = model.accounts.map { $0.id }
        var updates = 0
        model.languageChanged = { updates += 1 }
        model.language = .english
        XCTAssertEqual(L10n.text("Добавить"), "Add")
        model.language = .russian
        XCTAssertEqual(L10n.text("Добавить"), "Добавить")
        XCTAssertEqual(updates, 2)
        XCTAssertEqual(model.accounts.map { $0.id }, original)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "appLanguage"), preference)
    }

    func testShortcutDoesNotChangeOutsideRecording() throws {
        let button = RecorderButton()
        var changed = false
        button.onRecord = { _ in changed = true }
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown, location: .zero,
            modifierFlags: [.control, .option], timestamp: 0, windowNumber: 0, context: nil,
            characters: "a", charactersIgnoringModifiers: "a", isARepeat: false, keyCode: 0))
        button.keyDown(with: event)
        XCTAssertFalse(changed, "An idle shortcut button must not change preferences")
    }
    func testSearchSelectionAndWrapping() throws {
        let model = AppModel(demo: true)
        XCTAssertEqual(model.selected?.title, "GitHub")
        model.cycle(-1)
        XCTAssertEqual(model.selected?.title, "AWS")
        model.setQuery("GOO personal")
        XCTAssertEqual(model.filtered.count, 1)
        XCTAssertEqual(model.selected?.title, "Google")
        model.setQuery("not-found")
        XCTAssertNil(model.selected)
        model.cycle(1)
        XCTAssertNil(model.selected)
        model.resetPanel()
        XCTAssertEqual(model.filtered.count, 3)
    }
    func testDemoCannotPersistAccount() throws {
        let model = AppModel(demo: true)
        let account = try XCTUnwrap(model.accounts.first)
        XCTAssertThrowsError(try model.add(account))
        XCTAssertEqual(model.accounts.count, 3)
    }
}
