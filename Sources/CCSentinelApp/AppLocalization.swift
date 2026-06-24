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
        guard let resourceName = languagePreference.resourceName else {
            return .module
        }

        for candidate in resourceCandidates(for: resourceName) {
            if
                let path = Bundle.module.path(forResource: candidate, ofType: "lproj"),
                let bundle = Bundle(path: path)
            {
                return bundle
            }
        }

        return .module
    }

    private static func resourceCandidates(for resourceName: String) -> [String] {
        var candidates = [resourceName]

        if let matchingLocalization = Bundle.module.localizations.first(where: {
            $0.caseInsensitiveCompare(resourceName) == .orderedSame
        }) {
            candidates.append(matchingLocalization)
        }

        candidates.append(resourceName.lowercased())
        return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
    }
}
