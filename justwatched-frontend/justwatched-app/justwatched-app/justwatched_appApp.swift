//
//  justwatched_appApp.swift
//  justwatched-app
//
//  Created by Amina Yegenberdiyeva on 20.06.2025.
//

import SwiftUI

@main
struct justwatched_appApp: App {
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashScreenView(showSplash: $showSplash)
            } else {
                AuthGate()
            }
        }
    }
}
