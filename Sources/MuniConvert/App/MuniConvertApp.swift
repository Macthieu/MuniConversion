// SPDX-License-Identifier: GPL-3.0-only

import SwiftUI
import MuniConvertCore

@main
struct MuniConvertApp: App {
    var body: some Scene {
        WindowGroup("MuniConvert") {
            MainView()
        }
        .windowStyle(.titleBar)
    }
}
