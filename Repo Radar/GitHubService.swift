//
//  GitHubService.swift
//  Repo Radar
//
//  Created by Callum Matthews on 20/09/2025.
//

import Foundation

struct GitHubRepo: Codable {
    let fullName: String
    let name: String
    let owner: Owner
    let stargazersCount: Int
    let htmlUrl: String
    let updatedAt: String?

    struct Owner: Codable {
        let login: String
    }
}

struct GitHubRelease: Codable {
    let tagName: String
    let publishedAt: String?
    let htmlUrl: String
}

enum GitHubError: Error {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case rateLimited
    case notFound
    case invalidToken
    case unknown(Error)
    case httpError(status: Int, message: String?)
}

extension GitHubError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub URL."
        case .networkError(let err):
            return err.localizedDescription
        case .invalidResponse:
            return "Invalid response from GitHub."
        case .rateLimited:
            return "GitHub API rate limit exceeded."
        case .notFound:
            return "Repository not found."
        case .invalidToken:
            return "Invalid Personal Access Token."
        case .unknown(let err):
            return err.localizedDescription
        case .httpError(let status, let message):
            if let message, !message.isEmpty { return "HTTP \(status): \(message)" }
            return "HTTP \(status) error from GitHub."
        }
    }
}

class GitHubService {
    private let baseURL = "https://api.github.com"
    private let session: URLSession
    private var personalAccessToken: String?

    init() {
        self.session = URLSession.shared
    }

    func setPersonalAccessToken(_ token: String?) {
        self.personalAccessToken = token
    }

    // MARK: - Auth
    struct CurrentUser: Codable { let login: String }

    func verifyToken() async throws -> String {
        guard let token = personalAccessToken, !token.isEmpty else { throw GitHubError.invalidToken }
        guard let url = URL(string: "\(baseURL)/user") else { throw GitHubError.invalidURL }
        let request = makeRequest(url: url)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GitHubError.invalidResponse }
            switch http.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let me = try decoder.decode(CurrentUser.self, from: data)
                return me.login
            case 401:
                throw GitHubError.invalidToken
            case 403:
                throw GitHubError.rateLimited
            default:
                let message = parseErrorMessage(from: data)
                throw GitHubError.httpError(status: http.statusCode, message: message)
            }
        } catch {
            if let gh = error as? GitHubError { throw gh }
            throw GitHubError.networkError(error)
        }
    }

    private func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("RepoRadar/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        if let token = personalAccessToken, !token.isEmpty {
            // GitHub supports both Bearer and token; prefer Bearer
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func parseErrorMessage(from data: Data) -> String? {
        // GitHub error bodies are typically {"message":"...","documentation_url":"..."}
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else { return nil }
        if let msg = obj["message"] as? String { return msg }
        return nil
    }

    func fetchRepository(owner: String, name: String) async throws -> GitHubRepo {
        let endpoint = "\(baseURL)/repos/\(owner)/\(name)"
        guard let url = URL(string: endpoint) else {
            throw GitHubError.invalidURL
        }

        let request = makeRequest(url: url)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                do {
                    return try decoder.decode(GitHubRepo.self, from: data)
                } catch let decodingError as DecodingError {
                    if let body = String(data: data, encoding: .utf8) {
                        print("Decoding GitHubRepo failed: \(decodingError)\nBody: \(body)")
                    } else {
                        print("Decoding GitHubRepo failed: \(decodingError)")
                    }
                    throw decodingError
                }
            case 403:
                if let body = String(data: data, encoding: .utf8) {
                    print("GitHub 403: \(body)")
                }
                throw GitHubError.rateLimited
            case 404:
                throw GitHubError.notFound
            case 401:
                throw GitHubError.invalidToken
            default:
                let status = httpResponse.statusCode
                print("GitHub fetchRepository status: \(status)")
                if let body = String(data: data, encoding: .utf8) {
                    print("Body: \(body)")
                }
                let message = parseErrorMessage(from: data)
                throw GitHubError.httpError(status: status, message: message)
            }
        } catch {
            if let gitHubError = error as? GitHubError {
                throw gitHubError
            }
            throw GitHubError.networkError(error)
        }
    }

    func fetchLatestRelease(owner: String, name: String) async throws -> GitHubRelease? {
        let endpoint = "\(baseURL)/repos/\(owner)/\(name)/releases/latest"
        guard let url = URL(string: endpoint) else {
            throw GitHubError.invalidURL
        }

        let request = makeRequest(url: url)

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw GitHubError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                do {
                    return try decoder.decode(GitHubRelease.self, from: data)
                } catch let decodingError as DecodingError {
                    if let body = String(data: data, encoding: .utf8) {
                        print("Decoding GitHubRelease failed: \(decodingError)\nBody: \(body)")
                    } else {
                        print("Decoding GitHubRelease failed: \(decodingError)")
                    }
                    throw decodingError
                }
            case 404:
                // No releases found, this is normal
                return nil
            case 403:
                if let body = String(data: data, encoding: .utf8) {
                    print("GitHub 403 (release): \(body)")
                }
                throw GitHubError.rateLimited
            case 401:
                throw GitHubError.invalidToken
            default:
                let status = httpResponse.statusCode
                print("GitHub fetchLatestRelease status: \(status)")
                if let body = String(data: data, encoding: .utf8) {
                    print("Body: \(body)")
                }
                let message = parseErrorMessage(from: data)
                throw GitHubError.httpError(status: status, message: message)
            }
        } catch {
            if let gitHubError = error as? GitHubError {
                throw gitHubError
            }
            throw GitHubError.networkError(error)
        }
    }

    // Removed latest stargazer fetching to simplify UI and avoid stale data

    struct UserRepoSummary: Codable, Identifiable {
        let id: Int
        let name: String
        let fullName: String
        let htmlUrl: String
        let owner: GitHubRepo.Owner
        let stargazersCount: Int
    }

    // MARK: - Issues
    struct Issue: Codable {
        let title: String
        let htmlUrl: String
        let createdAt: String
        let pullRequest: PullRequestRef?

        struct PullRequestRef: Codable {
            let url: String
        }
    }

    private struct SearchIssuesResponse: Codable {
        struct Item: Codable {
            let title: String
            let htmlUrl: String
            let createdAt: String
        }
        let items: [Item]
    }

    func fetchLatestIssue(owner: String, name: String) async throws -> Issue? {
        // 1) Prefer Search API to guarantee PRs are excluded (is:issue)
        if let searchURL = URL(string: "\(baseURL)/search/issues?q=repo:\(owner)/\(name)+is:issue&sort=created&order=desc&per_page=1") {
            let request = makeRequest(url: searchURL)
            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse {
                    switch http.statusCode {
                    case 200:
                        let decoder = JSONDecoder()
                        decoder.keyDecodingStrategy = .convertFromSnakeCase
                        let res = try decoder.decode(SearchIssuesResponse.self, from: data)
                        if let item = res.items.first {
                            return Issue(title: item.title, htmlUrl: item.htmlUrl, createdAt: item.createdAt, pullRequest: nil)
                        } else {
                            return nil
                        }
                    case 401: throw GitHubError.invalidToken
                    case 403: break // fall back to issues endpoint (search is more restricted)
                    default:
                        // If search fails for any other reason, fall back
                        break
                    }
                }
            } catch {
                // Fall through to issues endpoint on any error
            }
        }

        // 2) Fallback: Issues endpoint (filter PRs client-side)
        guard let url = URL(string: "\(baseURL)/repos/\(owner)/\(name)/issues?per_page=10&state=all&sort=created&direction=desc") else { throw GitHubError.invalidURL }
        let request = makeRequest(url: url)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GitHubError.invalidResponse }
            switch http.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let issues = try decoder.decode([Issue].self, from: data)
                return issues.first(where: { $0.pullRequest == nil })
            case 404:
                return nil
            case 401:
                throw GitHubError.invalidToken
            case 403:
                throw GitHubError.rateLimited
            default:
                let message = parseErrorMessage(from: data)
                throw GitHubError.httpError(status: http.statusCode, message: message)
            }
        } catch {
            if let gh = error as? GitHubError { throw gh }
            throw GitHubError.networkError(error)
        }
    }

    func fetchUserRepos(page: Int = 1, perPage: Int = 50) async throws -> [UserRepoSummary] {
        guard perPage <= 100 else { return try await fetchUserRepos(page: page, perPage: 100) }
        // Include owned, collaborator and org repos; include private if scope allows
        guard let url = URL(string: "\(baseURL)/user/repos?page=\(page)&per_page=\(perPage)&sort=updated&affiliation=owner,collaborator,organization_member&visibility=all") else { throw GitHubError.invalidURL }
        let request = makeRequest(url: url)
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw GitHubError.invalidResponse }
            switch http.statusCode {
            case 200:
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode([UserRepoSummary].self, from: data)
            case 401:
                throw GitHubError.invalidToken
            case 403:
                throw GitHubError.rateLimited
            default:
                let message = parseErrorMessage(from: data)
                throw GitHubError.httpError(status: http.statusCode, message: message)
            }
        } catch {
            if let gh = error as? GitHubError { throw gh }
            throw GitHubError.networkError(error)
        }
    }

    func fetchUserReposAll(maxPages: Int = 10, perPage: Int = 50) async throws -> [UserRepoSummary] {
        var results: [UserRepoSummary] = []
        for page in 1...maxPages {
            let batch = try await fetchUserRepos(page: page, perPage: perPage)
            results.append(contentsOf: batch)
            if batch.count < perPage { break }
        }
        return results
    }

    func updateRepository(_ repository: Repository) async throws {
        do {
            // Fetch repository info
            let repo = try await fetchRepository(owner: repository.owner, name: repository.name)

            // Fetch latest release
            let release = try await fetchLatestRelease(owner: repository.owner, name: repository.name)
            // Fetch latest issue
            let latestIssue = try? await fetchLatestIssue(owner: repository.owner, name: repository.name)

            // Update repository data
            repository.previousStarCount = repository.starCount
            repository.starCount = repo.stargazersCount
            repository.lastUpdated = Date()

            if let release = release {
                repository.latestReleaseTag = release.tagName
                repository.latestReleaseName = release.tagName
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
}
