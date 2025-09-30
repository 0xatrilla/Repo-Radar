//
//  Repository.swift
//  Repo Radar
//
//  Created by Callum Matthews on 20/09/2025.
//

import Foundation
import SwiftData

enum PlatformType: String, CaseIterable, Codable {
    case github = "github"
    case gitlab = "gitlab"
    case bitbucket = "bitbucket"
    case sourceforge = "sourceforge"

    var displayName: String {
        switch self {
        case .github: return "GitHub"
        case .gitlab: return "GitLab"
        case .bitbucket: return "Bitbucket"
        case .sourceforge: return "SourceForge"
        }
    }

    var baseUrl: String {
        switch self {
        case .github: return "https://github.com"
        case .gitlab: return "https://gitlab.com"
        case .bitbucket: return "https://bitbucket.org"
        case .sourceforge: return "https://sourceforge.net"
        }
    }

    var icon: String? {
        switch self {
        case .github: return "star.fill"
        case .gitlab: return "cloud.fill"
        case .bitbucket: return "bucket.fill"
        case .sourceforge: return "doc.fill"
        }
    }
}

@Model
final class Repository: @unchecked Sendable {
    var owner: String
    var name: String
    var fullName: String
    var url: String
    var platform: PlatformType
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
    var latestIssueTitle: String?
    var latestIssueDate: Date?
    var stargazersCount: Int
    var forksCount: Int
    var openIssuesCount: Int
    var openPullRequestCount: Int
    var commitCount: Int
    var contributorCount: Int
    var lastCommitDate: Date?
    var issuesClosedToday: Int?

    init(owner: String, name: String, fullName: String, url: String, platform: PlatformType = .github) {
        self.owner = owner
        self.name = name
        self.fullName = fullName
        self.url = url
        self.platform = platform
        self.starCount = 0
        self.previousStarCount = 0
        self.lastUpdated = Date()
        self.notificationsEnabled = true
        self.lastChecked = Date()
        self.stargazersCount = 0
        self.forksCount = 0
        self.openIssuesCount = 0
        self.openPullRequestCount = 0
        self.commitCount = 0
        self.contributorCount = 0
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
