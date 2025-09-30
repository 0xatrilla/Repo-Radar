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
                if let base = NSImage(named: "menubar")?.trimmingTransparentPixels()?.resizedForMenuBar(size: NSSize(width: 18, height: 18)) {
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

        Window("Get Pro", id: "pro") {
            ProPaywallView()
                .frame(width: 520, height: 520)
        }

        Window("Analytics Dashboard", id: "analytics") {
            AnalyticsDashboardView()
                .frame(width: 900, height: 700)
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

    func trimmingTransparentPixels(threshold: UInt8 = 1) -> NSImage? {
        guard let cg = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let width = cg.width
        let height = cg.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let ctx = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo.rawValue) else { return nil }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = ctx.data else { return nil }

        let ptr = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

        var minX = width, minY = height, maxX = 0, maxY = 0
        for y in 0..<height {
            for x in 0..<width {
                let idx = y * bytesPerRow + x * bytesPerPixel
                let alpha = ptr[idx + 3]
                if alpha > threshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        if maxX <= minX || maxY <= minY { return self }

        let cropRect = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        guard let fullImage = ctx.makeImage(), let cropped = fullImage.cropping(to: cropRect) else { return nil }
        let result = NSImage(cgImage: cropped, size: NSSize(width: cropRect.width, height: cropRect.height))
        result.isTemplate = true
        return result
    }
}
