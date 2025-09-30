//
//  SourceForgeService.swift
//  Repo Radar
//
//  Created by Callum Matthews on 30/09/2025.
//

import Foundation

class SourceForgeService: RepositoryService {
    let platform: PlatformType = .sourceforge
    let baseURL: String = "https://sourceforge.net/rest"

    private let session: URLSession
    private var personalAccessToken: String?

    required init() {
        self.session = URLSession.shared
    }

    func setAccessToken(_ token: String?) {
        self.personalAccessToken = token
    }

    func verifyToken() async throws -> String {
        // SourceForge API doesn't have traditional authentication
        throw ServiceError.unsupportedPlatform
    }

    func fetchRepository(owner: String, name: String) async throws -> RepositoryInfo {
        // SourceForge project fetching would go here
        throw ServiceError.unsupportedPlatform
    }

    func fetchLatestRelease(owner: String, name: String) async throws -> ReleaseInfo? {
        // SourceForge release fetching would go here
        throw ServiceError.unsupportedPlatform
    }

    func fetchLatestIssue(owner: String, name: String) async throws -> IssueInfo? {
        // SourceForge doesn't have issues like GitHub/GitLab
        return nil
    }

    func fetchUserRepositories(page: Int = 1, perPage: Int = 50) async throws -> [RepositoryInfo] {
        // SourceForge user projects would go here
        throw ServiceError.unsupportedPlatform
    }

    func updateRepository(_ repository: Repository) async throws {
        throw ServiceError.unsupportedPlatform
    }
}