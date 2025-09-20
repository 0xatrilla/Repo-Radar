//
//  Repo_RadarApp.swift
//  Repo Radar
//
//  Created by Callum Matthews on 20/09/2025.
//

import SwiftUI
import SwiftData
import UserNotifications
import AppKit

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
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            Label {
                Text("Repo Radar")
            } icon: {
                if let base = NSImage(named: "menubar")?.resizedForMenuBar(size: NSSize(width: 20, height: 20)) {
                    Image(nsImage: base)
                        .renderingMode(.template)
                } else {
                    Image(systemName: "star.circle")
                }
            }
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsWindowView()
                .frame(width: 420, height: 340)
        }

        Window("Import My Repos", id: "import") {
            ImportMyReposWindow(viewModel: viewModel)
                .frame(width: 520, height: 480)
        }
    }
}

// MARK: - Helpers
private extension NSImage {
    func resizedForMenuBar(size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        defer { newImage.unlockFocus() }
        let rect = NSRect(origin: .zero, size: size)
        self.draw(in: rect, from: NSRect(origin: .zero, size: self.size), operation: .sourceOver, fraction: 1.0)
        newImage.isTemplate = true
        return newImage
    }
}
