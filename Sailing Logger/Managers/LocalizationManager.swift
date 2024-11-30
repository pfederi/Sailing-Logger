import Foundation

class LocalizationManager {
    static let shared = LocalizationManager()
    private var translations: [String: [String: String]] = [:]
    
    private init() {
        loadTranslations()
    }
    
    private func loadTranslations() {
        guard let url = Bundle.main.url(forResource: "de", withExtension: "po"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return
        }
        
        var currentLanguage = "de"
        var currentTranslations: [String: String] = [:]
        
        let lines = content.components(separatedBy: .newlines)
        var msgid = ""
        var msgstr = ""
        
        for line in lines {
            if line.hasPrefix("\"Language: ") {
                currentLanguage = String(line.dropFirst(10).dropLast(1))
            } else if line.hasPrefix("msgid \"") {
                msgid = String(line.dropFirst(7).dropLast(1))
            } else if line.hasPrefix("msgstr \"") {
                msgstr = String(line.dropFirst(8).dropLast(1))
                if !msgid.isEmpty {
                    currentTranslations[msgid] = msgstr
                }
                msgid = ""
                msgstr = ""
            }
        }
        
        translations[currentLanguage] = currentTranslations
    }
    
    func localizedString(_ key: String, language: String = Locale.current.language.languageCode?.identifier ?? "en") -> String {
        if language == "en" { return key }
        return translations[language]?[key] ?? key
    }
} 