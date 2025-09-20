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
    private let gitHubService = GitHubService()
    private var settings = Settings.shared
    private let pro = ProManager.shared
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Subscribe to settings changes
        settings.$personalAccessToken
            .sink { [weak self] token in
                self?.gitHubService.setPersonalAccessToken(token)
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
        print("viewModel.addRepository called with input: \(input)")

        await MainActor.run {
            isLoading = true
            errorMessage = nil
            isRateLimited = false
            print("viewModel state updated - isLoading: \(isLoading)")
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
            // Parse repository input
            print("About to parse input: \(input)")
            let (owner, name) = try parseRepositoryInput(input)
            print("Parsed successfully - owner: \(owner), name: \(name)")

            // Check if repository already exists
            if repositories.contains(where: { $0.owner == owner && $0.name == name }) {
                await MainActor.run {
                    errorMessage = "Repository is already being watched"
                    isLoading = false
                }
                return
            }

            // Fetch repository info to validate it exists
            let repo = try await gitHubService.fetchRepository(owner: owner, name: name)

            // Create new repository
            let repository = Repository(
                owner: repo.owner.login,
                name: repo.name,
                fullName: repo.fullName,
                url: repo.htmlUrl
            )

            // Update with latest data
            try await gitHubService.updateRepository(repository)

            // Save to database
            await MainActor.run {
                modelContext.insert(repository)
                repositories.append(repository)
                isLoading = false
            }

        } catch GitHubError.rateLimited {
            await MainActor.run {
                isRateLimited = true
                errorMessage = "GitHub API rate limit exceeded. Please add a Personal Access Token in settings to continue."
                isLoading = false
            }
        } catch GitHubError.notFound {
            await MainActor.run {
                errorMessage = "Repository not found. Please check the repository name and try again."
                isLoading = false
            }
        } catch GitHubError.invalidToken {
            await MainActor.run {
                errorMessage = "Invalid Personal Access Token. Please update it in Settings."
                isLoading = false
            }
        } catch GitHubError.httpError(let status, let message) {
            await MainActor.run {
                if status == 403 {
                    isRateLimited = true
                }
                let suffix = message?.isEmpty == false ? ": \(message!)" : ""
                errorMessage = "GitHub error (\(status))\(suffix)"
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
                try await gitHubService.updateRepository(repository)
            } catch GitHubError.rateLimited {
                await MainActor.run {
                    isRateLimited = true
                    errorMessage = "GitHub API rate limit exceeded. Please add a Personal Access Token in settings to continue."
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
                let starsURL = "https://github.com/\(repository.displayName)/stargazers"
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
                let issuesURL = "https://github.com/\(repository.displayName)/issues"
                content.userInfo = ["url": issuesURL]
                let request = UNNotificationRequest(
                    identifier: "issue-\(repository.id)-\(Int(Date().timeIntervalSince1970))",
                    content: content,
                    trigger: nil
                )
                do { try await center.add(request) } catch { print("Failed to send issue notification: \(error.localizedDescription)") }
            }

            // Update lastChecked per repo after evaluating notifications
            repository.lastChecked = Date()
        }
    }

    private func parseRepositoryInput(_ input: String) throws -> (String, String) {
        // Normalize input: take only the first non-empty token to avoid pasted newlines/extra text
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let primary = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .first ?? trimmed

        // Handle GitHub URLs
        if primary.contains("github.com") {
            if let url = URL(string: primary) {
                // Normalize potential trailing slash
                var path = url.path
                if path.hasSuffix("/") { path.removeLast() }

                // Split path components
                let comps = path.split(separator: "/").map(String.init)
                if comps.count >= 2 {
                    let owner = comps[0]
                    var repo = comps[1]
                    if repo.hasSuffix(".git") { repo = String(repo.dropLast(4)) }
                    if !owner.isEmpty && !repo.isEmpty { return (owner, repo) }
                }
            }
        }

        // Handle SSH format
        if primary.contains("git@github.com:") {
            let components = primary.components(separatedBy: ":")
            if components.count == 2 {
                let repoPart = components[1]
                let repoComponents = repoPart.components(separatedBy: "/")
                if repoComponents.count == 2 {
                    var repo = repoComponents[1]
                    if repo.hasSuffix(".git") { repo = String(repo.dropLast(4)) }
                    return (repoComponents[0], repo)
                }
            }
        }

        // Handle owner/repo format
        let components = primary.components(separatedBy: "/")
        if components.count == 2 && !components[0].isEmpty && !components[1].isEmpty {
            var repo = components[1]
            if repo.hasSuffix(".git") { repo = String(repo.dropLast(4)) }
            return (components[0], repo)
        }

        throw GitHubError.invalidURL
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
    func listMyRepos() async throws -> [GitHubService.UserRepoSummary] {
        return try await gitHubService.fetchUserReposAll()
    }

    deinit {
        timer?.invalidate()
    }
}
