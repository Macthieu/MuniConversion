// SPDX-License-Identifier: GPL-3.0-only

import Foundation

enum LocalizationService {
    private static let resourceBundleNames = [
        "MuniConvert_MuniConvertCore.bundle",
        "MuniConvertCore_MuniConvertCore.bundle",
        "MuniConvert_MuniConvert.bundle"
    ]

    static func tr(_ key: String, language: AppLanguage) -> String {
        let bundle = bundle(for: language)
        return NSLocalizedString(key, tableName: "Localizable", bundle: bundle, value: key, comment: "")
    }

    static func tr(_ key: String, language: AppLanguage, _ arguments: [CVarArg]) -> String {
        let format = tr(key, language: language)
        return String(format: format, locale: Locale(identifier: language.localeIdentifier), arguments: arguments)
    }

    private static func bundle(for language: AppLanguage) -> Bundle {
        let base = baseResourceBundle()
        guard let path = base.path(forResource: language.rawValue, ofType: "lproj"),
              let localizedBundle = Bundle(path: path) else {
            return base
        }
        return localizedBundle
    }

    private static func baseResourceBundle() -> Bundle {
        for url in candidateResourceBundleURLs() {
            guard FileManager.default.fileExists(atPath: url.path),
                  let bundle = Bundle(url: url) else {
                continue
            }
            return bundle
        }
        return Bundle.main
    }

    private static func candidateResourceBundleURLs() -> [URL] {
        var candidates: [URL] = []
        for bundleName in resourceBundleNames {
            if let resourceURL = Bundle.main.resourceURL {
                candidates.append(resourceURL.appendingPathComponent(bundleName))
            }

            let mainBundleURL = Bundle.main.bundleURL
            candidates.append(mainBundleURL.appendingPathComponent(bundleName))
            candidates.append(mainBundleURL.appendingPathComponent("Contents/Resources/\(bundleName)"))
            candidates.append(mainBundleURL.appendingPathComponent("Resources/\(bundleName)"))

            if let executablePath = CommandLine.arguments.first {
                let executableURL = URL(fileURLWithPath: executablePath)
                let executableDir = executableURL.deletingLastPathComponent()
                candidates.append(executableDir.appendingPathComponent(bundleName))
                candidates.append(executableDir.appendingPathComponent("../Resources/\(bundleName)").standardizedFileURL)
                candidates.append(executableDir.appendingPathComponent("../../\(bundleName)").standardizedFileURL)

                var searchDir = executableDir
                for _ in 0..<6 {
                    candidates.append(searchDir.appendingPathComponent(bundleName))
                    candidates.append(searchDir.appendingPathComponent("Resources/\(bundleName)"))
                    searchDir.deleteLastPathComponent()
                }
            }

            var cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            for _ in 0..<6 {
                candidates.append(cwd.appendingPathComponent(bundleName))
                candidates.append(cwd.appendingPathComponent("Resources/\(bundleName)"))
                candidates.append(cwd.appendingPathComponent(".build/arm64-apple-macosx/debug/\(bundleName)"))
                candidates.append(cwd.appendingPathComponent(".build/arm64-apple-macosx/release/\(bundleName)"))
                candidates.append(cwd.appendingPathComponent(".build/x86_64-apple-macosx/debug/\(bundleName)"))
                candidates.append(cwd.appendingPathComponent(".build/x86_64-apple-macosx/release/\(bundleName)"))
                cwd.deleteLastPathComponent()
            }
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.path).inserted }
    }
}
