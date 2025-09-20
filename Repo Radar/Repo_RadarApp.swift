//
//  Repo_RadarApp.swift
//  Repo Radar
//
//  Created by Callum Matthews on 20/09/2025.
//

import SwiftUI
import SwiftData
import UserNotifications

@main
struct Repo_RadarApp: App {
    @StateObject private var viewModel: RepoRadarViewModel

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Repository.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        let container = sharedModelContainer
        let context = ModelContext(container)
        _viewModel = StateObject(wrappedValue: RepoRadarViewModel(modelContext: context))
    }

    var body: some Scene {
        MenuBarExtra("Repo Radar", systemImage: "star.circle") {
            MenuBarView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsWindowView()
                .frame(width: 420, height: 340)
        }
    }
}
