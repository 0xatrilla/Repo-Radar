//
//  GitLabService.swift
//  Repo Radar
//
//  Created by Callum Matthews on 30/09/2025.
//

import Foundation

class GitLabService: RepositoryService {
    let platform: PlatformType = .gitlab
    let baseURL: String = "https://gitlab.com/api/v4"

    private let session: URLSession
    private var personalAccessToken: String?

    required init() {
        self.session = URLSession.shared
    }

    func setAccessToken(_ token: String?) {
        self.personalAccessToken = token
    }

    func verifyToken() async throws -> String {
        guard let token = personalAccessToken, !token.isEmpty else { throw ServiceError.invalidToken }
        guard let url = URL(string: "\(baseURL)/user") else { throw ServiceError.invalidURL }
        let request = makeRequest(url: url)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
            switch http.statusCode {
            case 200:
                let decoder = JSONDecoder()
                let user = try decoder.decode(GitLabUser.self, from: data)
                return user.username
            case 401:
                throw ServiceError.invalidToken
            case 403:
                throw ServiceError.rateLimited
            default:
                let message = parseErrorMessage(from: data)
                throw ServiceError.httpError(status: http.statusCode, message: message)
            }
        } catch {
            if let serviceError = error as? ServiceError { throw serviceError }
            throw ServiceError.networkError(error)
        }
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("RepoRadar/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        if let token = personalAccessToken, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else { return nil }
        if let msg = obj["message"] as? String { return msg }
        if let error = obj["error"] as? String { return error }
        return nil
    }

    func fetchRepository(owner: String, name: String) async throws -> RepositoryInfo {
        // GitLab uses project paths instead of owner/name
        let projectPath = "\(owner)/\(name)"
        let encodedPath = projectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectPath
        let endpoint = "\(baseURL)/projects/\(encodedPath)"
        guard let url = URL(string: endpoint) else {
            throw ServiceError.invalidURL
        }

        let request = makeRequest(url: url)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let project = try decoder.decode(GitLabProject.self, from: data)
                return RepositoryInfo(
                    fullName: project.pathWithNamespace,
                    name: project.name,
                    owner: project.namespace.fullPath,
                    starCount: project.starCount,
                    url: project.webUrl,
                    lastUpdated: project.lastActivityAt,
                    platform: .gitlab
                )
            case 403:
                throw ServiceError.rateLimited
            case 404:
                throw ServiceError.notFound
            case 401:
                throw ServiceError.invalidToken
            default:
                let status = httpResponse.statusCode
                let message = parseErrorMessage(from: data)
                throw ServiceError.httpError(status: status, message: message)
            }
        } catch {
            if let serviceError = error as? ServiceError { throw serviceError }
            throw ServiceError.networkError(error)
        }
    }

    func fetchLatestRelease(owner: String, name: String) async throws -> ReleaseInfo? {
        let projectPath = "\(owner)/\(name)"
        let encodedPath = projectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectPath
        let endpoint = "\(baseURL)/projects/\(encodedPath)/releases"
        guard let url = URL(string: endpoint) else {
            throw ServiceError.invalidURL
        }

        let request = makeRequest(url: url)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let releases = try decoder.decode([GitLabRelease].self, from: data)
                if let latest = releases.first {
                    return ReleaseInfo(
                        tagName: latest.tagName,
                        name: latest.name,
                        publishedAt: latest.releasedAt,
                        url: latest.webUrl
                    )
                }
                return nil
            case 403:
                throw ServiceError.rateLimited
            case 401:
                throw ServiceError.invalidToken
            case 404:
                return nil
            default:
                let status = httpResponse.statusCode
                let message = parseErrorMessage(from: data)
                throw ServiceError.httpError(status: status, message: message)
            }
        } catch {
            if let serviceError = error as? ServiceError { throw serviceError }
            throw ServiceError.networkError(error)
        }
    }

    func fetchLatestIssue(owner: String, name: String) async throws -> IssueInfo? {
        let projectPath = "\(owner)/\(name)"
        let encodedPath = projectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? projectPath
        let endpoint = "\(baseURL)/projects/\(encodedPath)/issues"
        var comps = URLComponents(string: endpoint)
        comps?.queryItems = [
            URLQueryItem(name: "state", value: "opened"),
            URLQueryItem(name: "sort", value: "created_desc"),
            URLQueryItem(name: "per_page", value: "1")
        ]
        guard let url = comps?.url else { throw ServiceError.invalidURL }

        let request = makeRequest(url: url)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ServiceError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let issues = try decoder.decode([GitLabIssue].self, from: data)
                if let latest = issues.first, let createdAt = latest.createdAt {
                    return IssueInfo(
                        title: latest.title,
                        url: latest.webUrl,
                        createdAt: createdAt,
                        isPullRequest: false
                    )
                }
                return nil
            case 403:
                throw ServiceError.rateLimited
            case 401:
                throw ServiceError.invalidToken
            case 404:
                return nil
            default:
                let status = httpResponse.statusCode
                let message = parseErrorMessage(from: data)
                throw ServiceError.httpError(status: status, message: message)
            }
        } catch {
            if let serviceError = error as? ServiceError { throw serviceError }
            throw ServiceError.networkError(error)
        }
    }

    func fetchUserRepositories(page: Int = 1, perPage: Int = 50) async throws -> [RepositoryInfo] {
        guard perPage <= 100 else { return try await fetchUserRepositories(page: page, perPage: 100) }

        var comps = URLComponents(string: "\(baseURL)/projects")
        comps?.queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "per_page", value: "\(perPage)"),
            URLQueryItem(name: "membership", value: "true"),
            URLQueryItem(name: "order_by", value: "last_activity_at"),
            URLQueryItem(name: "sort", value: "desc")
        ]

        guard let url = comps?.url else { throw ServiceError.invalidURL }
        let request = makeRequest(url: url)

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
            switch http.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let projects = try decoder.decode([GitLabProject].self, from: data)
                return projects.map { project in
                    RepositoryInfo(
                        fullName: project.pathWithNamespace,
                        name: project.name,
                        owner: project.namespace.fullPath,
                        starCount: project.starCount,
                        url: project.webUrl,
                        lastUpdated: project.lastActivityAt,
                        platform: .gitlab
                    )
                }
            case 401:
                throw ServiceError.invalidToken
            case 403:
                throw ServiceError.rateLimited
            default:
                let message = parseErrorMessage(from: data)
                throw ServiceError.httpError(status: http.statusCode, message: message)
            }
        } catch {
            if let serviceError = error as? ServiceError { throw serviceError }
            throw ServiceError.networkError(error)
        }
    }

    func updateRepository(_ repository: Repository) async throws {
        do {
            let repo = try await fetchRepository(owner: repository.owner, name: repository.name)
            let release = try await fetchLatestRelease(owner: repository.owner, name: repository.name)
            let latestIssue = try? await fetchLatestIssue(owner: repository.owner, name: repository.name)

            repository.previousStarCount = repository.starCount
            repository.starCount = repo.starCount
            repository.lastUpdated = Date()

            if let release = release {
                repository.latestReleaseTag = release.tagName
                repository.latestReleaseName = release.name
                if let publishedAt = release.publishedAt {
                    let formatter = ISO8601DateFormatter()
                    repository.latestReleaseDate = formatter.date(from: publishedAt)
                }
            } else {
                repository.latestReleaseTag = nil
                repository.latestReleaseName = nil
                repository.latestReleaseDate = nil
            }

            if let issue = latestIssue {
                repository.latestIssueTitle = issue.title
                let formatter = ISO8601DateFormatter()
                repository.latestIssueDate = formatter.date(from: issue.createdAt)
            }

        } catch {
            throw error
        }
    }

    // MARK: - GitLab-specific types
    struct GitLabUser: Codable {
        let id: Int
        let username: String
        let name: String
        let email: String?
    }

    struct GitLabProject: Codable {
        let id: Int
        let name: String
        let path: String
        let pathWithNamespace: String
        let description: String?
        let webUrl: String
        let starCount: Int
        let forksCount: Int
        let lastActivityAt: String?
        let createdAt: String?
        let namespace: Namespace
        let defaultBranch: String?

        struct Namespace: Codable {
            let id: Int
            let name: String
            let path: String
            let kind: String
            let fullPath: String
        }
    }

    struct GitLabRelease: Codable {
        let tagName: String
        let name: String
        let description: String?
        let releasedAt: String?
        let webUrl: String
    }

    struct GitLabIssue: Codable {
        let id: Int
        let iid: Int
        let title: String
        let description: String?
        let webUrl: String
        let createdAt: String?
        let updatedAt: String?
        let state: String
        let author: Author

        struct Author: Codable {
            let id: Int
            let name: String
            let username: String
            let state: String
        }
    }
}