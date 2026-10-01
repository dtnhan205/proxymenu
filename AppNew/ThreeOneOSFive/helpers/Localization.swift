import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    static let storageKey = "appLanguage"

    case english = "en"
    case vietnamese = "vi"
    case simplifiedChinese = "zh-Hans"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    /// Ngôn ngữ hiển thị trong picker cài đặt / onboarding.
    /// Loại bỏ `simplifiedChinese` theo yêu cầu (chỉ giữ English + Vietnamese).
    static var selectableCases: [AppLanguage] {
        allCases.filter { $0 != .simplifiedChinese }
    }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .vietnamese: return "Tiếng Việt"
        case .simplifiedChinese: return "简体中文"
        }
    }

    /// Quốc kỳ hiển thị cạnh tên ngôn ngữ trong segmented picker (cyberpunk style).
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .vietnamese: return "🇻🇳"
        case .simplifiedChinese: return "🇨🇳"
        }
    }

    /// Tên ngắn cho chip nhỏ (vd "EN", "VI", "中"). Khi picker đã có flag, dùng
    /// tên ngắn để tiết kiệm chiều ngang.
    var shortName: String {
        switch self {
        case .english: return "EN"
        case .vietnamese: return "VI"
        case .simplifiedChinese: return "中"
        }
    }

    func text(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: key, table: nil)
    }

    func text(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: locale, arguments: arguments)
    }

    private var localizedBundle: Bundle {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
}

private struct AppLanguageEnvironmentKey: EnvironmentKey {
    static let defaultValue = AppLanguage.english
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageEnvironmentKey.self] }
        set { self[AppLanguageEnvironmentKey.self] = newValue }
    }
}

extension ExploitStatus {
    func displayText(language: AppLanguage) -> String {
        switch self {
        case .notStarted:
            return language.text("status.not_attempted")
        case .success(let method):
            let localizedMethod = method == "Simulator preview"
                ? language.text("method.simulator_preview")
                : method
            return language.text("status.ok_via", localizedMethod)
        case .failed(let method, let code):
            return language.text("status.failed_via", method, code)
        case .unsupported(let message):
            return language.text("status.unsupported_reason", message)
        }
    }
}
