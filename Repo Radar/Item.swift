//
//  Repository.swift
//  Repo Radar
//
//  Created by Callum Matthews on 20/09/2025.
//

import Foundation
import SwiftData

@Model
final class Repository {
    var owner: String
    var name: String
    var fullName: String
    var url: String
    var latestReleaseTag: String?
    var latestReleaseName: String?
    var latestReleaseDate: Date?
    var starCount: Int
    var previousStarCount: Int
    var lastUpdated: Date
    var notificationsEnabled: Bool
    var lastChecked: Date
    var latestStarUser: String?
    var latestStarDate: Date?

    init(owner: String, name: String, fullName: String, url: String) {
        self.owner = owner
        self.name = name
        self.fullName = fullName
        self.url = url
        self.starCount = 0
        self.previousStarCount = 0
        self.lastUpdated = Date()
        self.notificationsEnabled = true
        self.lastChecked = Date()
    }

    var hasNewRelease: Bool {
        guard let latestReleaseDate = latestReleaseDate else { return false }
        return latestReleaseDate > lastChecked
    }

    var starDelta: Int {
        starCount - previousStarCount
    }

    var displayName: String {
        "\(owner)/\(name)"
    }
}
