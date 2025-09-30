//
//  RepositoryAnalytics.swift
//  Repo Radar
//
//  Created by Claude on 30/09/2025.
//

import Foundation
import SwiftData

@Model
final class RepositoryAnalytics: @unchecked Sendable {
    var repositoryID: PersistentIdentifier
    var platform: String
    var owner: String
    var name: String
    var fullName: String

    // Basic statistics
    var starCount: Int
    var forkCount: Int
    var watcherCount: Int
    var issueCount: Int
    var openPullRequestCount: Int

    // Activity tracking
    var commitCount: Int
    var contributorCount: Int
    var releaseCount: Int
    var lastCommitDate: Date?
    var lastReleaseDate: Date?

    // Growth metrics
    var starsGainedToday: Int
    var starsGainedWeek: Int
    var starsGainedMonth: Int
    var issuesOpenedToday: Int
    var issuesClosedToday: Int
    var pullRequestsOpenedToday: Int
    var pullRequestsMergedToday: Int

    // Health metrics
    var healthScore: Double // 0.0 - 100.0
    var activityLevel: ActivityLevel
    var lastUpdated: Date

    // Historical data for charts (stored as JSON)
    var dailyStarHistory: String // JSON array of daily star counts
    var dailyCommitHistory: String // JSON array of daily commit counts
    var dailyIssueHistory: String // JSON array of daily issue counts

    init(repositoryID: PersistentIdentifier, platform: String, owner: String, name: String, fullName: String) {
        self.repositoryID = repositoryID
        self.platform = platform
        self.owner = owner
        self.name = name
        self.fullName = fullName

        // Initialize with default values
        self.starCount = 0
        self.forkCount = 0
        self.watcherCount = 0
        self.issueCount = 0
        self.openPullRequestCount = 0
        self.commitCount = 0
        self.contributorCount = 0
        self.releaseCount = 0
        self.starsGainedToday = 0
        self.starsGainedWeek = 0
        self.starsGainedMonth = 0
        self.issuesOpenedToday = 0
        self.issuesClosedToday = 0
        self.pullRequestsOpenedToday = 0
        self.pullRequestsMergedToday = 0
        self.healthScore = 50.0 // Neutral score
        self.activityLevel = .low
        self.lastUpdated = Date()

        // Initialize empty history arrays
        self.dailyStarHistory = "[]"
        self.dailyCommitHistory = "[]"
        self.dailyIssueHistory = "[]"
    }

    enum ActivityLevel: String, CaseIterable, Codable {
        case veryLow = "very_low"
        case low = "low"
        case moderate = "moderate"
        case high = "high"
        case veryHigh = "very_high"

        var displayName: String {
            switch self {
            case .veryLow: return "Very Low"
            case .low: return "Low"
            case .moderate: return "Moderate"
            case .high: return "High"
            case .veryHigh: return "Very High"
            }
        }

        var color: String {
            switch self {
            case .veryLow: return "gray"
            case .low: return "blue"
            case .moderate: return "green"
            case .high: return "orange"
            case .veryHigh: return "red"
            }
        }
    }

    // Helper methods for historical data
    func updateDailyStarHistory(_ stars: Int) {
        var history = getDailyStarHistory()
        history.append(stars)
        // Keep only last 30 days
        if history.count > 30 {
            history.removeFirst()
        }
        dailyStarHistory = try! JSONSerialization.data(withJSONObject: history).base64EncodedString()
    }

    func getDailyStarHistory() -> [Int] {
        guard let data = Data(base64Encoded: dailyStarHistory),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Int] else {
            return []
        }
        return array
    }

    func updateDailyCommitHistory(_ commits: Int) {
        var history = getDailyCommitHistory()
        history.append(commits)
        if history.count > 30 {
            history.removeFirst()
        }
        dailyCommitHistory = try! JSONSerialization.data(withJSONObject: history).base64EncodedString()
    }

    func getDailyCommitHistory() -> [Int] {
        guard let data = Data(base64Encoded: dailyCommitHistory),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Int] else {
            return []
        }
        return array
    }

    func updateDailyIssueHistory(_ issues: Int) {
        var history = getDailyIssueHistory()
        history.append(issues)
        if history.count > 30 {
            history.removeFirst()
        }
        dailyIssueHistory = try! JSONSerialization.data(withJSONObject: history).base64EncodedString()
    }

    func getDailyIssueHistory() -> [Int] {
        guard let data = Data(base64Encoded: dailyIssueHistory),
              let array = try? JSONSerialization.jsonObject(with: data) as? [Int] else {
            return []
        }
        return array
    }

    // Health score calculation
    func calculateHealthScore() -> Double {
        // Simple algorithm based on multiple factors
        var score = 50.0 // Base score

        // Activity factor (0-25 points)
        let recentActivity = starsGainedWeek + issuesClosedToday + pullRequestsMergedToday
        if recentActivity > 50 {
            score += 25
        } else if recentActivity > 20 {
            score += 15
        } else if recentActivity > 5 {
            score += 5
        }

        // Issue resolution factor (0-15 points)
        if issueCount > 0 {
            let resolutionRate = Double(issuesClosedToday) / Double(issueCount) * 100
            score += min(resolutionRate * 0.15, 15)
        }

        // Community engagement factor (0-10 points)
        if starCount > 100 {
            score += 10
        } else if starCount > 50 {
            score += 7
        } else if starCount > 10 {
            score += 3
        }

        // Recency factor (0-10 points)
        if let lastCommit = lastCommitDate {
            let daysSinceCommit = Date().timeIntervalSince(lastCommit) / (24 * 60 * 60)
            if daysSinceCommit < 7 {
                score += 10
            } else if daysSinceCommit < 30 {
                score += 5
            }
        }

        return min(score, 100.0)
    }
}