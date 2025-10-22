//
//  OpenAlbumApp.swift
//  OpenAlbum
//
//  Created by Tomikawa Sotaro on 2025/10/09.
//

import SwiftData
import SwiftUI

@main
struct OpenAlbumApp: App {
  var sharedModelContainer: ModelContainer = {
    let schema = Schema(versionedSchema: ItemSchemaV001.self)
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(
        for: schema, migrationPlan: ItemMigrationPlan.self, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
  }
}
