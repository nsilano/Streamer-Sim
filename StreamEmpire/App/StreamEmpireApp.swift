import SwiftUI
import UIKit

@main
struct StreamEmpireApp: App {
    @StateObject private var store = GameStore()

    init() {
        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = UIColor(red: 0.05, green: 0.04, blue: 0.12, alpha: 1)
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
