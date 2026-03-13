import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case traditionalChinese = "zh-Hant"
    case japanese = "ja"
    case korean = "ko"
    case indonesian = "id"
    case vietnamese = "vi"
    case german = "de"
    case french = "fr"
    case spanish = "es"
    case portuguese = "pt"
    case brazilianPortuguese = "pt-BR"
    case russian = "ru"

    var id: String { rawValue }

    var bundleLanguageCode: String? {
        switch self {
        case .system: nil
        default: rawValue
        }
    }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        default:
            Locale(identifier: rawValue)
        }
    }

    var displayName: String {
        switch self {
        case .system: L10n.tr("Follow System")
        case .english: "English"
        case .simplifiedChinese: "简体中文"
        case .traditionalChinese: "繁體中文"
        case .japanese: "日本語"
        case .korean: "한국어"
        case .indonesian: "Bahasa Indonesia"
        case .vietnamese: "Tiếng Việt"
        case .german: "Deutsch"
        case .french: "Français"
        case .spanish: "Español"
        case .portuguese: "Português"
        case .brazilianPortuguese: "Português do Brasil"
        case .russian: "Русский"
        }
    }
}

enum AppLocalization {
    static func selectedLanguage() -> AppLanguage {
        guard
            let rawValue = UserDefaults.standard.string(forKey: Constants.appLanguageKey),
            let language = AppLanguage(rawValue: rawValue)
        else {
            return .system
        }
        return language
    }

    static func setSelectedLanguage(_ language: AppLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: Constants.appLanguageKey)
        NotificationCenter.default.post(name: .appLanguageChanged, object: nil)
    }

    static var locale: Locale {
        selectedLanguage().locale
    }

    static func localizedString(_ key: String, table: String? = nil) -> String {
        let table = table ?? "Localizable"
        switch selectedLanguage() {
        case .system:
            return Bundle.main.localizedString(forKey: key, value: key, table: table)
        default:
            let bundle = bundle(for: selectedLanguage()) ?? Bundle.main
            let localized = bundle.localizedString(forKey: key, value: key, table: table)
            if localized != key {
                return localized
            }
            return Bundle.main.localizedString(forKey: key, value: key, table: table)
        }
    }

    private static func bundle(for language: AppLanguage) -> Bundle? {
        guard let code = language.bundleLanguageCode else { return nil }

        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        if let baseCode = Locale(identifier: code).language.languageCode?.identifier,
           let path = Bundle.main.path(forResource: baseCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        return nil
    }
}

final class LocalizationObserver: ObservableObject {
    @Published private(set) var version = 0
    private var cancellable: AnyCancellable?

    init(center: NotificationCenter = .default) {
        cancellable = center.publisher(for: .appLanguageChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.version += 1
            }
    }
}

extension Notification.Name {
    static let appLanguageChanged = Notification.Name("appLanguageChanged")
}
