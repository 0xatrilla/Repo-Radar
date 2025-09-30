//
//  BitbucketService.swift
//  Repo Radar
//
//  Created by Callum Matthews on 30/09/2025.
//

import Foundation

class BitbucketService: RepositoryService {
    let platform: PlatformType = .bitbucket
    let baseURL: String = "https://api.bitbucket.org/2.0"

    private let session: URLSession
    private var personalAccessToken: String?

    required init() {
        self.session = URLSession.shared
    }

    func setAccessToken(_ token: String?) {
        self.personalAccessToken = token
    }

    func verifyToken() async throws -> String {
        // Bitbucket verification would go here
        throw ServiceError.unsupportedPlatform
    }

    func fetchRepository(owner: String, name: String) async throws -> RepositoryInfo {
        // Bitbucket repository fetching would go here
        throw ServiceError.unsupportedPlatform
    }

    func fetchLatestRelease(owner: String, name: String) async throws -> ReleaseInfo? {
        // Bitbucket doesn't have a native releases concept like GitHub
        return nil
    }

    func fetchLatestIssue(owner: String, name: String) async throws -> IssueInfo? {
        // Bitbucket issue fetching would go here
        throw ServiceError.unsupportedPlatform
    }

    func fetchUserRepositories(page: Int = 1, perPage: Int = 50) async throws -> [RepositoryInfo] {
        // Bitbucket user repositories would go here
        throw ServiceError.unsupportedPlatform
    }

    func updateRepository(_ repository: Repository) async throws {
        throw ServiceError.unsupportedPlatform
    }
}