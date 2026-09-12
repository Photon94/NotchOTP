import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable {
    case system, russian = "ru", english = "en", chinese = "zh-Hans", german = "de", french = "fr", hindi = "hi"
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .system: return L10n.text("Как в macOS")
        case .russian: return "Русский"
        case .english: return "English"
        case .chinese: return "简体中文"
        case .german: return "Deutsch"
        case .french: return "Français"
        case .hindi: return "हिन्दी"
        }
    }
    public func resolved(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard self == .system else { return self }
        for identifier in preferredLanguages {
            let code = identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first
            if code == "ru" { return .russian }
            if code == "en" { return .english }
            if code == "zh" {
                let parts = identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" })
                // Do not replace a Traditional Chinese preference with Simplified.
                let traditional = parts.contains("hant") ||
                    (!parts.contains("hans") && parts.contains(where: { ["tw", "hk", "mo"].contains(String($0)) }))
                if !traditional { return .chinese }
            }
            if code == "de" { return .german }
            if code == "fr" { return .french }
            if code == "hi" { return .hindi }
        }
        return .english
    }
}

/// Shared by native menus, SwiftUI and validation errors. Compiled into the app
/// so translations also work in standalone SwiftPM and signed app builds.
public enum L10n {
    private static let lock = NSLock()
    private static var selection = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "appLanguage") ?? "") ?? .system
    public static var language: AppLanguage {
        get { lock.lock(); defer { lock.unlock() }; return selection }
        set { lock.lock(); defer { lock.unlock() }; selection = newValue }
    }
    public static func text(_ key: String, _ arguments: CVarArg...) -> String {
        let resolved = language.resolved()
        let format = resolved == .russian ? key : (catalog(for: resolved)[key] ?? english[key] ?? key)
        guard !arguments.isEmpty else { return format }
        return String(format: format, locale: Locale(identifier: resolved.rawValue), arguments: arguments)
    }

    static func catalog(for language: AppLanguage) -> [String: String] {
        switch language {
        case .chinese: return chinese
        case .german: return german
        case .french: return french
        case .hindi: return hindi
        case .english, .system: return english
        case .russian: return [:] // Russian source keys are the original catalog.
        }
    }

    static let english: [String: String] = [
        "Не удалось прочитать хранилище. Данные не изменены.": "Could not read the vault. Your data has not been changed.",
        "Хранилище содержит повреждённые данные. Оно не будет перезаписано.": "The vault contains damaged data. It will not be overwritten.",
        "NotchOTP — аккаунты двухфакторной аутентификации": "NotchOTP — two-factor authentication accounts",
        "Проверьте секретный ключ: нужны буквы A–Z и цифры 2–7 в формате Base32.": "Check the secret key: use letters A–Z and digits 2–7 in Base32 format.",
        "Укажите название аккаунта (до 200 символов) и сервиса (до 100).": "Enter an account name (up to 200 characters) and service name (up to 100).",
        "Секретный ключ пустой или слишком длинный.": "The secret key is empty or too long.",
        "Поддерживаются только SHA1, SHA256 и SHA512.": "Only SHA1, SHA256 and SHA512 are supported.",
        "Поддерживаются 6 или 8 цифр и период от 1 до 3600 секунд.": "Use 6 or 8 digits and a period between 1 and 3600 seconds.",
        "Нужна ссылка otpauth://totp/… из настройки двухфакторной аутентификации.": "Use an otpauth://totp/… link from your two-factor authentication settings.",
        "Этот QR-код не является TOTP. HOTP и пакетный перенос Google пока не поддерживаются.": "This QR code is not TOTP. HOTP and Google bulk migration are not supported yet.",
        "В ссылке повторяются параметры. Получите новый QR-код у сервиса.": "The link contains duplicate parameters. Get a new QR code from the service.",
        "В QR-коде отсутствует секретный ключ.": "The QR code does not contain a secret key.",
        "Названия сервиса в QR-коде не совпадают. Проверьте источник.": "The service names in the QR code do not match. Check its source.",
        "Некорректное число цифр или период в QR-коде.": "The QR code contains an invalid digit count or period.",
        "Нажмите сочетание…": "Press shortcut…",
        "Это деморежим. Перезапустите приложение, чтобы добавить свой аккаунт.": "This is demo mode. Restart the app to add your own account.",
        "Сначала откройте доступ к связке ключей.": "Unlock Keychain first.",
        "Этот аккаунт уже добавлен.": "This account has already been added.",
        "Ключ исчезнет из NotchOTP. Убедитесь, что у вас есть другой способ входа в этот аккаунт.": "The key will be removed from NotchOTP. Make sure you have another way to sign in to this account.",
        "Отмена": "Cancel",
        "Удалить": "Delete",
        "Не удалось скопировать код. Попробуйте ещё раз.": "Could not copy the code. Try again.",
        "Не удалось зарегистрировать сочетание. Выберите другое в настройках; панель доступна через значок ключа в строке меню.": "Could not register the shortcut. Choose another in settings; you can open the panel using the key icon in the menu bar.",
        "Аккаунты и настройки…": "Accounts and Settings…",
        "Завершить NotchOTP": "Quit NotchOTP",
        "Правка": "Edit",
        "Отменить": "Undo",
        "Вырезать": "Cut",
        "Копировать": "Copy",
        "Вставить": "Paste",
        "Выбрать всё": "Select All",
        "Это сочетание занято. Попробуйте другое; прежнее сочетание продолжает работать.": "This shortcut is already in use. Try another; your previous shortcut still works.",
        "Выберите изображение с QR-кодом": "Choose an image with a QR code",
        "Не удалось открыть изображение. Выберите PNG или JPEG с QR-кодом.": "Could not open the image. Choose a PNG or JPEG containing a QR code.",
        "На изображении несколько аккаунтов. Обрежьте его до одного QR-кода.": "The image contains multiple accounts. Crop it to a single QR code.",
        "QR-код TOTP не найден. Выберите более чёткое изображение кода из настроек безопасности сервиса. Пакетный перенос Google не поддерживается.": "No TOTP QR code found. Choose a clearer image from the service’s security settings. Google bulk migration is not supported.",
        "Ваши коды. Под рукой.": "Your codes. Within reach.",
        "Вызовите панель, выберите аккаунт и нажмите Enter.": "Open the panel, select an account and press Enter.",
        "Деморежим · показаны тестовые аккаунты": "Demo mode · sample accounts",
        "Аккаунты": "Accounts",
        "Читаем…": "Reading…",
        "QR из файла": "QR from file",
        "Добавить": "Add",
        "Глобальное сочетание": "Global shortcut",
        "Нажмите справа, затем введите новое сочетание.": "Click the button, then press a new shortcut.",
        "Используйте Control, Option или Command вместе с клавишей. Escape — отмена.": "Use Control, Option or Command with a key. Escape cancels.",
        "Аккаунт": "Account",
        "Текст": "Type",
        "Поиск": "Search",
        "Закрыть": "Close",
        "Показать панель": "Show panel",
        "Ключи хранятся в связке ключей этого Mac. Всё работает локально.": "Keys are stored in this Mac’s Keychain. Everything runs locally.",
        "Добавить аккаунт?": "Add account?",
        "Не удалось выполнить действие": "Could not complete the action",
        "Понятно": "OK",
        "Откройте доступ к связке ключей": "Unlock Keychain",
        "Повторить": "Try again",
        "Добавьте первый аккаунт": "Add your first account",
        "Выберите QR-код из настроек двухфакторной\nаутентификации или введите секретный ключ.": "Choose a QR code from your two-factor authentication\nsettings or enter a secret key.",
        "Показать": "Show",
        "Удалить аккаунт": "Delete account",
        "Новый аккаунт": "New account",
        "Способ": "Method",
        "Секретный ключ": "Secret key",
        "Ссылка otpauth": "otpauth link",
        "Сервис": "Service",
        "Например, GitHub": "For example, GitHub",
        "Например, work или email": "For example, work or email",
        "Секретный ключ Base32": "Base32 secret key",
        "Ключ из настроек двухфакторной аутентификации": "Key from your two-factor authentication settings",
        "Дополнительные параметры": "Advanced settings",
        "Алгоритм": "Algorithm",
        "Цифры": "Digits",
        "Период, секунд": "Period, seconds",
        "Ссылка из настроек сервиса": "Link from the service’s settings",
        "Ключ останется в связке ключей этого Mac.": "The key will stay in this Mac’s Keychain.",
        "Период должен быть целым числом секунд.": "The period must be a whole number of seconds.",
        "Некорректные параметры кода или системное время.": "Invalid code parameters or system time.",
        "Этот алгоритм не поддерживается. Используйте SHA1, SHA256 или SHA512.": "This algorithm is not supported. Use SHA1, SHA256 or SHA512.",
        "Связка ключей закрыта": "Keychain is locked",
        "Открыть настройки": "Open settings",
        "Настроить NotchOTP": "Set up NotchOTP",
        "Скопировано": "Copied",
        "Enter — скопировать · Tab — следующий · Начните печатать для поиска": "Enter to copy · Tab for next · Type to search",
        "Найти аккаунт…": "Find account…",
        "Ничего не найдено": "No accounts found",
        "↑↓ Выбрать": "↑↓ Select",
        "↵ Копировать": "↵ Copy",
        "Язык": "Language",
        "Как в macOS": "Use macOS language",
        "Применяется сразу, без перезапуска.": "Changes take effect immediately.",
        "Удалить %@?": "Delete %@?",
        "Удалить %@": "Delete %@",
        "Показать код   %@": "Show code   %@",
        "%d цифр · %d сек": "%d digits · %d sec",
        "%d цифр · %d сек · %@": "%d digits · %d sec · %@",
        "Осталось %d секунд": "Seconds remaining: %d",
        "Ошибка %d": "Error %d",
        "Связка ключей недоступна: %@. Разблокируйте её и попробуйте снова.": "Keychain is unavailable: %@. Unlock it and try again.",
    ]
}
