// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum CollisionPolicy: String, CaseIterable, Identifiable, Codable {
    case skipExisting
    case overwrite
    case renameWithSuffix

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .skipExisting:
            return "Ignorer si existe"
        case .overwrite:
            return "Remplacer"
        case .renameWithSuffix:
            return "Renommer automatiquement"
        }
    }

    var compactDisplayName: String {
        switch self {
        case .skipExisting:
            return "Ignorer"
        case .overwrite:
            return "Remplacer"
        case .renameWithSuffix:
            return "Renommer"
        }
    }
}
