//
//  MultiPlatformTests.swift
//  Repo Radar Tests
//
//  Created by Claude on 30/09/2025.
//

import Foundation
import Testing

@testable import Repo_Radar

@Suite("Multi-Platform Support Tests")
struct MultiPlatformTests {

    @Test("URL Parser detects GitHub URLs correctly")
    func urlParserDetectsGitHub() throws {
        let testCases = [
            "https://github.com/octocat/Hello-World",
            "git@github.com:octocat/Hello-World.git",
            "octocat/Hello-World"
        ]

        for testCase in testCases {
            let (platform, owner, name) = try RepositoryURLParser.parse(from: testCase)
            #expect(platform == .github)
            #expect(owner == "octocat")
            #expect(name == "Hello-World")
        }
    }

    @Test("URL Parser detects GitLab URLs correctly")
    func urlParserDetectsGitLab() throws {
        let testCases = [
            "https://gitlab.com/gitlab-org/gitlab",
            "git@gitlab.com:gitlab-org/gitlab.git"
        ]

        for testCase in testCases {
            let (platform, owner, name) = try RepositoryURLParser.parse(from: testCase)
            #expect(platform == .gitlab)
            #expect(owner == "gitlab-org")
            #expect(name == "gitlab")
        }
    }

    @Test("URL Parser detects Bitbucket URLs correctly")
    func urlParserDetectsBitbucket() throws {
        let testCase = "https://bitbucket.org/atlassian/python-bitbucket"
        let (platform, owner, name) = try RepositoryURLParser.parse(from: testCase)
        #expect(platform == .bitbucket)
        #expect(owner == "atlassian")
        #expect(name == "python-bitbucket")
    }

    @Test("URL Parser detects SourceForge URLs correctly")
    func urlParserDetectsSourceForge() throws {
        let testCase = "https://sourceforge.net/projects/sevenzip/"
        let (platform, owner, name) = try RepositoryURLParser.parse(from: testCase)
        #expect(platform == .sourceforge)
        #expect(owner == "sevenzip")
        #expect(name == "sevenzip")
    }

    @Test("RepositoryServiceFactory creates correct services")
    func serviceFactoryCreatesCorrectServices() {
        let githubService = RepositoryServiceFactory.createService(for: .github)
        #expect(githubService.platform == .github)
        #expect(githubService is GitHubService)

        let gitlabService = RepositoryServiceFactory.createService(for: .gitlab)
        #expect(gitlabService.platform == .gitlab)
        #expect(gitlabService is GitLabService)

        let bitbucketService = RepositoryServiceFactory.createService(for: .bitbucket)
        #expect(bitbucketService.platform == .bitbucket)
        #expect(bitbucketService is BitbucketService)

        let sourceforgeService = RepositoryServiceFactory.createService(for: .sourceforge)
        #expect(sourceforgeService.platform == .sourceforge)
        #expect(sourceforgeService is SourceForgeService)
    }
}