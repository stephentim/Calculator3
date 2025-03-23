//
//  Calculator3App.swift
//  Calculator3
//
//  Created by Stephen Tim on 2025/3/21.
//

import SwiftUI

@main
struct Calculator3App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: HistoryEntry.self) // 启用自动保存
    }
}
