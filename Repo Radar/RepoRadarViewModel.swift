//
//  RepoRadarViewModel.swift
//  Repo Radar
//
//  Created by Callum Matthews on 20/09/2025.
//

import Foundation
import SwiftData
import UserNotifications
import Combine

class RepoRadarViewModel: ObservableObject {
    @Published var repositories: [Repository] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isRateLimited = false

    private let modelContext: ModelContext
    private var services: [PlatformType: RepositoryService] = [:]
    private var settings = Settings.shared
    private let pro = ProManager.shared
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Initialize services for all platforms
        for platform in PlatformType.allCases {
            services[platform] = RepositoryServiceFactory.createService(for: platform)
        }

        // Subscribe to settings changes and update all services
        settings.$personalAccessToken
            .sink { [weak self] token in
                self?.services.values.forEach { $0.setAccessToken(token) }
            }
            .store(in: &cancellables)

        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
        }

        // Load repositories from database
        loadRepositories()

        // Start polling
        startPolling()
    }

    private func loadRepositories() {
        let descriptor = FetchDescriptor<Repository>(
            sortBy: [SortDescriptor(\.fullName)]
        )

        do {
            repositories = try modelContext.fetch(descriptor)
        } catch {
            errorMessage = "Failed to load repositories: \(error.localizedDescription)"
        }
    }

    func addRepository(from input: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            isRateLimited = false
        }

        do {
            // Gate free users at 3 repositories
            if !pro.isSubscribed && repositories.count >= 3 {
                await MainActor.run {
                    errorMessage = "Free plan limit reached. Get Pro to track more than 3 repos."
                    isLoading = false
                }
                return
            }

            // Parse repository input with platform detection
            let (platform, owner, name) = try RepositoryURLParser.parse(from: input)

            // Check if repository already exists
            if repositories.contains(where: { $0.owner == owner && $0.name == name && $0.platform == platform }) {
                await MainActor.run {
                    errorMessage = "Repository is already being watched"
                    isLoading = false
                }
                return
            }

            // Get appropriate service
            guard let service = services[platform] else {
                await MainActor.run {
                    errorMessage = "\(platform.displayName) is not yet supported"
                    isLoading = false
                }
                return
            }

            // Fetch repository info to validate it exists
            let repo = try await service.fetchRepository(owner: owner, name: name)

            // Create new repository
            let repository = Repository(
                owner: owner,
                name: name,
                fullName: repo.fullName,
                url: repo.url,
                platform: platform
            )

            // Update with latest data
            try await service.updateRepository(repository)

            // Save to database
            await MainActor.run {
                modelContext.insert(repository)
                repositories.append(repository)
                isLoading = false
            }

        } catch ServiceError.rateLimited {
            await MainActor.run {
                isRateLimited = true
                errorMessage = "API rate limit exceeded. Please add a Personal Access Token in settings to continue."
                isLoading = false
            }
        } catch ServiceError.notFound {
            await MainActor.run {
                errorMessage = "Repository not found. Please check the repository name and try again."
                isLoading = false
            }
        } catch ServiceError.invalidToken {
            await MainActor.run {
                errorMessage = "Invalid Personal Access Token. Please update it in Settings."
                isLoading = false
            }
        } catch ServiceError.unsupportedPlatform {
            await MainActor.run {
                errorMessage = "This platform is not yet supported."
                isLoading = false
            }
        } catch ServiceError.httpError(let status, let message) {
            await MainActor.run {
                if status == 403 {
                    isRateLimited = true
                }
                let suffix = message?.isEmpty == false ? ": \(message!)" : ""
                errorMessage = "API error (\(status))\(suffix)"
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to add repository: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }

    func removeRepository(_ repository: Repository) {
        modelContext.delete(repository)
        repositories.removeAll { $0.id == repository.id }
    }

    func refreshRepositories() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
            isRateLimited = false
        }

        for repository in repositories {
            do {
                guard let service = services[repository.platform] else {
                    print("No service available for \(repository.platform.displayName)")
                    continue
                }
                try await service.updateRepository(repository)
            } catch ServiceError.rateLimited {
                await MainActor.run {
                    isRateLimited = true
                    errorMessage = "API rate limit exceeded. Please add a Personal Access Token in settings to continue."
                    isLoading = false
                }
                return
            } catch {
                // Continue with other repositories even if one fails
                print("Failed to update \(repository.displayName): \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            isLoading = false
        }

        // Notifications
        await postNotificationsIfNeeded()
    }

    private func postNotificationsIfNeeded() async {
        guard settings.notificationsEnabled else { return }

        let center = UNUserNotificationCenter.current()

        for repository in repositories {
            // Update analytics data first
            await updateAnalytics(for: repository)

            // Release notifications
            if settings.notifyOnRelease,
               repository.hasNewRelease,
               let releaseTag = repository.latestReleaseTag {
                let content = UNMutableNotificationContent()
                content.title = "New Release: \(repository.displayName)"
                content.body = "Released \(releaseTag)"
                content.sound = UNNotificationSound.default
                content.userInfo = ["url": repository.url]
                let request = UNNotificationRequest(
                    identifier: "release-\(repository.id)",
                    content: content,
                    trigger: nil
                )
                do { try await center.add(request) } catch { print("Failed to send notification: \(error.localizedDescription)") }
            }

            // Star notifications
            if settings.notifyOnStar, repository.starDelta > 0 {
                let content = UNMutableNotificationContent()
                content.title = "Stars: \(repository.displayName)"
                content.body = "+\(repository.starDelta) new star\(repository.starDelta == 1 ? "" : "s")"
                content.sound = UNNotificationSound.default
                let starsURL = getStarsURL(for: repository)
                content.userInfo = ["url": starsURL]
                let request = UNNotificationRequest(
                    identifier: "stars-\(repository.id)-\(Int(Date().timeIntervalSince1970))",
                    content: content,
                    trigger: nil
                )
                do { try await center.add(request) } catch { print("Failed to send star notification: \(error.localizedDescription)") }
            }

            // Issue notifications
            if settings.notifyOnIssue,
               let issueDate = repository.latestIssueDate,
               issueDate > repository.lastChecked,
               let title = repository.latestIssueTitle {
                let content = UNMutableNotificationContent()
                content.title = "New Issue: \(repository.displayName)"
                content.body = title
                content.sound = UNNotificationSound.default
                let issuesURL = getIssuesURL(for: repository)
                content.userInfo = ["url": issuesURL]
                let request = UNNotificationRequest(
                    identifier: "issue-\(repository.id)-\(Int(Date().timeIntervalSince1970))",
                    content: content,
                    trigger: nil
                )
                do { try await center.add(request) } catch { print("Failed to send issue notification: \(error.localizedDescription)") }
            }

            // Pro analytics notifications
            if pro.isSubscribed {
                await sendAnalyticsNotifications(for: repository)
            }

            // Update lastChecked per repo after evaluating notifications
            repository.lastChecked = Date()
        }
    }

    private func updateAnalytics(for repository: Repository) async {
        guard pro.isSubscribed else { return }

        // Fetch or create analytics for this repository
        let analytics: RepositoryAnalytics
        let descriptor = FetchDescriptor<RepositoryAnalytics>()

        do {
            let allAnalytics = try modelContext.fetch(descriptor)
            if let existingAnalytics = allAnalytics.first(where: { $0.fullName == repository.fullName }) {
                analytics = existingAnalytics
            } else {
                analytics = RepositoryAnalytics(
                    repositoryID: repository.persistentModelID,
                    platform: repository.platform.rawValue,
                    owner: repository.owner,
                    name: repository.name,
                    fullName: repository.fullName
                )
                modelContext.insert(analytics)
            }
        } catch {
            print("Failed to fetch analytics: \(error.localizedDescription)")
            return
        }

        // Update analytics with current data
        await MainActor.run {
            // Basic statistics
            analytics.starCount = repository.stargazersCount
            analytics.forkCount = repository.forksCount
            analytics.issueCount = repository.openIssuesCount
            analytics.openPullRequestCount = repository.openPullRequestCount

            // Activity tracking
            analytics.commitCount = repository.commitCount
            analytics.contributorCount = repository.contributorCount
            analytics.lastCommitDate = repository.lastCommitDate
            analytics.lastUpdated = Date()

            // Growth metrics
            analytics.starsGainedToday = repository.starDelta
            analytics.starsGainedWeek = analytics.starsGainedWeek + repository.starDelta

            // Track daily history
            analytics.updateDailyStarHistory(repository.stargazersCount)
            analytics.updateDailyCommitHistory(repository.commitCount)
            analytics.updateDailyIssueHistory(repository.openIssuesCount)

            // Update health score
            analytics.healthScore = analytics.calculateHealthScore()

            // Determine activity level based on recent changes
            let recentActivity = repository.starDelta + (repository.issuesClosedToday ?? 0)
            if recentActivity > 50 {
                analytics.activityLevel = .veryHigh
            } else if recentActivity > 20 {
                analytics.activityLevel = .high
            } else if recentActivity > 5 {
                analytics.activityLevel = .moderate
            } else if recentActivity > 0 {
                analytics.activityLevel = .low
            } else {
                analytics.activityLevel = .veryLow
            }
        }
    }

    private func sendAnalyticsNotifications(for repository: Repository) async {
        guard pro.isSubscribed else { return }

        let center = UNUserNotificationCenter.current()

        // Get current analytics
        let descriptor = FetchDescriptor<RepositoryAnalytics>()
        let allAnalytics = try? modelContext.fetch(descriptor)
        guard let analytics = allAnalytics?.first(where: { $0.fullName == repository.fullName }) else { return }

        // Health score change notification
        if settings.notifyOnHealthChange,
           let lastHealthScore = UserDefaults.standard.object(forKey: "health-\(repository.id)") as? Double,
           abs(analytics.healthScore - lastHealthScore) > 20 {
            let content = UNMutableNotificationContent()
            content.title = "Health Score Changed: \(repository.displayName)"
            content.body = "Score \(analytics.healthScore > lastHealthScore ? "improved" : "declined") to \(Int(analytics.healthScore))%"
            content.sound = UNNotificationSound.default
            content.userInfo = ["url": repository.url, "type": "analytics"]
            let request = UNNotificationRequest(
                identifier: "health-\(repository.id)-\(Int(Date().timeIntervalSince1970))",
                content: content,
                trigger: nil
            )
            do { try await center.add(request) } catch { print("Failed to send health notification: \(error.localizedDescription)") }

            UserDefaults.standard.set(analytics.healthScore, forKey: "health-\(repository.id)")
        }

        // Activity spike notification
        if settings.notifyOnActivitySpike,
           analytics.activityLevel == .high || analytics.activityLevel == .veryHigh {
            let content = UNMutableNotificationContent()
            content.title = "Activity Spike: \(repository.displayName)"
            content.body = "\(analytics.activityLevel.displayName) activity detected"
            content.sound = UNNotificationSound.default
            content.userInfo = ["url": repository.url, "type": "analytics"]
            let request = UNNotificationRequest(
                identifier: "activity-\(repository.id)-\(Int(Date().timeIntervalSince1970))",
                content: content,
                trigger: nil
            )
            do { try await center.add(request) } catch { print("Failed to send activity notification: \(error.localizedDescription)") }
        }

        // Milestone notifications
        if settings.notifyOnMilestone {
            let milestones = [
                (analytics.starCount, 100, "stars"),
                (analytics.starCount, 500, "stars"),
                (analytics.starCount, 1000, "stars"),
                (analytics.forkCount, 50, "forks"),
                (analytics.forkCount, 100, "forks"),
                (Int(analytics.healthScore), 80, "health score"),
                (Int(analytics.healthScore), 90, "health score")
            ]

            for (value, threshold, type) in milestones {
                if value == threshold {
                    let notifiedKey = "milestone-\(repository.id)-\(type)-\(threshold)"
                    if !UserDefaults.standard.bool(forKey: notifiedKey) {
                        let content = UNMutableNotificationContent()
                        content.title = "Milestone Reached: \(repository.displayName)"
                        content.body = "Reached \(threshold) \(type)!"
                        content.sound = UNNotificationSound.default
                        content.userInfo = ["url": repository.url, "type": "analytics"]
                        let request = UNNotificationRequest(
                            identifier: "milestone-\(repository.id)-\(Int(Date().timeIntervalSince1970))",
                            content: content,
                            trigger: nil
                        )
                        do { try await center.add(request) } catch { print("Failed to send milestone notification: \(error.localizedDescription)") }

                        UserDefaults.standard.set(true, forKey: notifiedKey)
                    }
                }
            }
        }
    }

    private func startPolling() {
        // Stop existing timer
        timer?.invalidate()

        // Start new timer
        timer = Timer.scheduledTimer(withTimeInterval: settings.refreshInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.refreshRepositories()
            }
        }
    }

    // MARK: - User Repos
    func listMyRepos() async throws -> [RepositoryInfo] {
        guard let service = services[.github] else {
            throw ServiceError.unsupportedPlatform
        }
        return try await service.fetchUserRepositories(page: 1, perPage: 100)
    }

    // MARK: - URL Helpers
    private func getStarsURL(for repository: Repository) -> String {
        switch repository.platform {
        case .github:
            return "https://github.com/\(repository.displayName)/stargazers"
        case .gitlab:
            return "\(repository.url)/-/starrers"
        case .bitbucket:
            return "\(repository.url)#network"
        case .sourceforge:
            return repository.url
        }
    }

    private func getIssuesURL(for repository: Repository) -> String {
        switch repository.platform {
        case .github:
            return "https://github.com/\(repository.displayName)/issues"
        case .gitlab:
            return "\(repository.url)/-/issues"
        case .bitbucket:
            return "\(repository.url)/issues"
        case .sourceforge:
            return repository.url
        }
    }

    deinit {
        timer?.invalidate()
    }
}
