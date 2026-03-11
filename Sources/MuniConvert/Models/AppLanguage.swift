// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case french = "fr"
    case english = "en"
    case spanish = "es"

    var id: String { rawValue }

    var localeIdentifier: String { rawValue }

    func displayName(in language: AppLanguage) -> String {
        switch (self, language) {
        case (.french, .french):
            return "Français"
        case (.english, .french):
            return "Anglais"
        case (.spanish, .french):
            return "Espagnol"
        case (.french, .english):
            return "French"
        case (.english, .english):
            return "English"
        case (.spanish, .english):
            return "Spanish"
        case (.french, .spanish):
            return "Francés"
        case (.english, .spanish):
            return "Inglés"
        case (.spanish, .spanish):
            return "Español"
        }
    }
}
