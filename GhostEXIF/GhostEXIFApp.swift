//
//  GhostEXIFApp.swift
//  GhostEXIF
//
//  Created by Jim Washkau on 5/22/26.
//

import SwiftUI

@main
struct GhostEXIFApp: App {
    @StateObject private var purchases = PurchaseManager.shared

    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .task {
                    await purchases.prepare()
                }
        }
    }
}
