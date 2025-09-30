//
//  RepositoryService.swift
//  Repo Radar
//
//  Created by Callum Matthews on 30/09/2025.
//

import Foundation

// Generic repository data structure
struct RepositoryInfo: Codable, Identifiable {
    let id = UUID()
    let fullName: String
    let name: String
    let owner: String
    let starCount: Int
    let url: String
    let lastUpdated: String?
    let platform: PlatformType
}

struct ReleaseInfo: Codable {
    let tagName: String
    let name: String
    let publishedAt: String?
    let url: String
}

struct IssueInfo: Codable {
    let title: String
    let url: String
    let createdAt: String
    let isPullRequest: Bool
}

enum ServiceError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case rateLimited
    case notFound
    case invalidToken
    case unsupportedPlatform
    case httpError(status: Int, message: String?)
    case unknown(Error)
}

extension ServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid repository URL."
        case .networkError(let err):
            return err.localizedDescription
        case .invalidResponse:
            return "Invalid response from server."
        case .rateLimited:
            return "API rate limit exceeded."
        case .notFound:
            return "Repository not found."
        case .invalidToken:
            return "Invalid access token."
        case .unsupportedPlatform:
            return "This platform is not supported."
        case .unknown(let err):
            return err.localizedDescription
        case .httpError(let status, let message):
            if let message, !message.isEmpty { return "HTTP \(status): \(message)" }
            return "HTTP \(status) error."
        }
    }
}

// Protocol for all repository services
protocol RepositoryService {
    var platform: PlatformType { get }
    var baseURL: String { get }

    init()

    // Authentication
    func setAccessToken(_ token: String?)
    func verifyToken() async throws -> String

    // Repository operations
    func fetchRepository(owner: String, name: String) async throws -> RepositoryInfo
    func fetchLatestRelease(owner: String, name: String) async throws -> ReleaseInfo?
    func fetchLatestIssue(owner: String, name: String) async throws -> IssueInfo?

    // User repositories
    func fetchUserRepositories(page: Int, perPage: Int) async throws -> [RepositoryInfo]

    // Update repository with latest data
    func updateRepository(_ repository: Repository) async throws
}

// Service factory for creating instances
class RepositoryServiceFactory {
    static func createService(for platform: PlatformType) -> RepositoryService {
        switch platform {
        case .github:
            return GitHubService()
        case .gitlab:
            return GitLabService()
        case .bitbucket:
            return BitbucketService()
        case .sourceforge:
            return SourceForgeService()
        }
    }

    static func service(for url: URL) -> RepositoryService? {
        let host = url.host?.lowercased() ?? ""

        if host.contains("github.com") {
            return GitHubService()
        } else if host.contains("gitlab.com") || host.contains("gitlab") {
            return GitLabService()
        } else if host.contains("bitbucket.org") {
            return BitbucketService()
        } else if host.contains("sourceforge.net") {
            return SourceForgeService()
        }

        return nil
    }
}

// MARK: - Helper for parsing repository URLs
struct RepositoryURLParser {
    static func parse(from input: String) throws -> (platform: PlatformType, owner: String, name: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let primary = trimmed
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .first ?? trimmed

        // Try to detect platform from URL
        if let url = URL(string: primary) {
            let host = url.host?.lowercased() ?? ""

            if host.contains("github.com") {
                return try parseGitHubURL(url)
            } else if host.contains("gitlab.com") || host.contains("gitlab") {
                return try parseGitLabURL(url)
            } else if host.contains("bitbucket.org") {
                return try parseBitbucketURL(url)
            } else if host.contains("sourceforge.net") {
                return try parseSourceForgeURL(url)
            }
        }

        // Handle SSH URLs
        if primary.contains("git@") {
            if primary.contains("github.com") {
                return try parseGitHubSSH(primary)
            } else if primary.contains("gitlab") {
                return try parseGitLabSSH(primary)
            }
        }

        // Default to GitHub for owner/repo format
        let components = primary.components(separatedBy: "/")
        if components.count == 2 && !components[0].isEmpty && !components[1].isEmpty {
            var repo = components[1]
            if repo.hasSuffix(".git") { repo = String(repo.dropLast(4)) }
            return (.github, components[0], repo)
        }

        throw ServiceError.invalidURL
    }

    private static func parseGitHubURL(_ url: URL) throws -> (PlatformType, String, String) {
        var path = url.path
        if path.hasSuffix("/") { path.removeLast() }

        let comps = path.split(separator: "/").map(String.init)
        if comps.count >= 2 {
            let owner = comps[0]
            var repo = comps[1]
            if repo.hasSuffix(".git") { repo = String(repo.dropLast(4)) }
            if !owner.isEmpty && !repo.isEmpty { return (.github, owner, repo) }
        }

        throw ServiceError.invalidURL
    }

    private static func parseGitLabURL(_ url: URL) throws -> (PlatformType, String, String) {
        var path = url.path
        if path.hasSuffix("/") { path.removeLast() }

        let comps = path.split(separator: "/").map(String.init)
        if comps.count >= 2 {
            // GitLab URLs can have group structure, so we need to handle nested paths
            let repo = comps.last ?? ""
            let ownerComponents = comps.dropLast()
            let owner = ownerComponents.joined(separator: "/")

            if !owner.isEmpty && !repo.isEmpty && repo.hasSuffix(".git") {
                return (.gitlab, owner, String(repo.dropLast(4)))
            } else if !owner.isEmpty && !repo.isEmpty {
                return (.gitlab, owner, repo)
            }
        }

        throw ServiceError.invalidURL
    }

    private static func parseBitbucketURL(_ url: URL) throws -> (PlatformType, String, String) {
        var path = url.path
        if path.hasSuffix("/") { path.removeLast() }

        let comps = path.split(separator: "/").map(String.init)
        if comps.count >= 2 {
            let owner = comps[0]
            var repo = comps[1]
            if repo.hasSuffix(".git") { repo = String(repo.dropLast(4)) }
            if !owner.isEmpty && !repo.isEmpty { return (.bitbucket, owner, repo) }
        }

        throw ServiceError.invalidURL
    }

    private static func parseSourceForgeURL(_ url: URL) throws -> (PlatformType, String, String) {
        // SourceForge URLs are complex, try to extract from path
        var path = url.path
        if path.hasSuffix("/") { path.removeLast() }

        let comps = path.split(separator: "/").map(String.init)
        if let projectIndex = comps.firstIndex(of: "projects"),
           projectIndex + 1 < comps.count {
            let projectName = comps[projectIndex + 1]
            return (.sourceforge, projectName, projectName)
        }

        throw ServiceError.invalidURL
    }

    private static func parseGitHubSSH(_ input: String) throws -> (PlatformType, String, String) {
        let components = input.components(separatedBy: ":")
        if components.count == 2 {
            let repoPart = components[1]
            let repoComponents = repoPart.components(separatedBy: "/")
            if repoComponents.count == 2 {
                var repo = repoComponents[1]
                if repo.hasSuffix(".git") { repo = String(repo.dropLast(4)) }
                return (.github, repoComponents[0], repo)
            }
        }

        throw ServiceError.invalidURL
    }

    private static func parseGitLabSSH(_ input: String) throws -> (PlatformType, String, String) {
        let components = input.components(separatedBy: ":")
        if components.count == 2 {
            let repoPart = components[1]
            let repoComponents = repoPart.components(separatedBy: "/")
            if repoComponents.count >= 2 {
                let owner = repoComponents.dropLast().joined(separator: "/")
                var repo = repoComponents.last ?? ""
                if repo.hasSuffix(".git") { repo = String(repo.dropLast(4)) }
                return (.gitlab, owner, repo)
            }
        }

        throw ServiceError.invalidURL
    }
}