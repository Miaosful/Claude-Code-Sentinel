import Foundation
import CCSentinelCore

enum AppLanguagePreference: String, CaseIterable, Sendable {
    case system
    case chineseSimplified = "zh-Hans"
    case english = "en"

    var titleKey: L10nKey {
        switch self {
        case .system:
            return .languageSystem
        case .chineseSimplified:
            return .languageChineseSimplified
        case .english:
            return .languageEnglish
        }
    }

    var resourceName: String? {
        switch self {
        case .system:
            return nil
        case .chineseSimplified:
            return "zh-Hans"
        case .english:
            return "en"
        }
    }
}

enum AppLocalizer {
    static func localized(_ key: L10nKey, languagePreference: AppLanguagePreference) -> String {
        bundle(for: languagePreference).localizedString(forKey: key.rawValue, value: nil, table: nil)
    }

    private static func bundle(for languagePreference: AppLanguagePreference) -> Bundle {
        guard
            let resourceName = languagePreference.resourceName,
            let path = Bundle.module.path(forResource: resourceName, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .module
        }
        return bundle
    }
}
