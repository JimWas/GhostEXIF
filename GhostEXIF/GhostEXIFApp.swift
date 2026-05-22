//
//  GhostEXIFApp.swift
//  GhostEXIF
//
//  Created by Jim Washkau on 5/22/26.
//

import SwiftUI
import CoreData

@main
struct GhostEXIFApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
