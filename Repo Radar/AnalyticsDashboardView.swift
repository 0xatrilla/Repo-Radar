//
//  AnalyticsDashboardView.swift
//  Repo Radar
//
//  Created by Claude on 30/09/2025.
//

import SwiftUI
import SwiftData

struct AnalyticsDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var pro = ProManager.shared

    @Query private var repositories: [Repository]
    @Query private var analytics: [RepositoryAnalytics]

    @State private var selectedTimeRange: TimeRange = .week
    @State private var selectedRepository: Repository?
    @State private var isLoading = false

    enum TimeRange: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
        case year = "Year"

        var days: Int {
            switch self {
            case .day: return 1
            case .week: return 7
            case .month: return 30
            case .year: return 365
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if !pro.isSubscribed {
                        ProUpgradeCard()
                    }

                    // Overview Section
                    OverviewSection(
                        repositories: repositories,
                        analytics: analytics,
                        selectedTimeRange: selectedTimeRange
                    )

                    // Repository Selector
                    if repositories.count > 1 {
                        RepositorySelector(
                            repositories: repositories,
                            selectedRepository: $selectedRepository
                        )
                    }

                    // Detailed Analytics
                    if let selectedRepo = selectedRepository ?? repositories.first,
                       let repoAnalytics = analytics.first(where: { $0.repositoryID == selectedRepo.persistentModelID }) {
                        DetailedAnalyticsView(
                            repository: selectedRepo,
                            analytics: repoAnalytics
                        )
                    }

                    // Charts Section
                    if !analytics.isEmpty {
                        ChartsSection(
                            analytics: analytics,
                            selectedTimeRange: selectedTimeRange,
                            selectedRepository: selectedRepository
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Analytics Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.menu)
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button("Refresh") {
                        refreshAnalytics()
                    }
                    .disabled(isLoading)
                }
            }
        }
        .onAppear {
            selectedRepository = repositories.first
        }
    }

    private func refreshAnalytics() {
        isLoading = true
        // This would trigger analytics refresh in a real implementation
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
        }
    }
}

// MARK: - Overview Section
struct OverviewSection: View {
    let repositories: [Repository]
    let analytics: [RepositoryAnalytics]
    let selectedTimeRange: AnalyticsDashboardView.TimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    title: "Total Repos",
                    value: "\(repositories.count)",
                    change: nil,
                    trend: nil,
                    color: .blue
                )

                MetricCard(
                    title: "Total Stars",
                    value: "\(analytics.reduce(0) { $0 + $1.starCount })",
                    change: "+\(analytics.reduce(0) { $0 + $1.starsGainedWeek })",
                    trend: .up,
                    color: .yellow
                )

                MetricCard(
                    title: "Open Issues",
                    value: "\(analytics.reduce(0) { $0 + $1.issueCount })",
                    change: nil,
                    trend: nil,
                    color: .red
                )

                MetricCard(
                    title: "Avg Health",
                    value: "\(Int(analytics.isEmpty ? 0 : analytics.reduce(0) { $0 + $1.healthScore } / Double(analytics.count)))%",
                    change: nil,
                    trend: nil,
                    color: .green
                )
            }
        }
    }
}

// MARK: - Repository Selector
struct RepositorySelector: View {
    let repositories: [Repository]
    @Binding var selectedRepository: Repository?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Repository")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(repositories) { repo in
                        Button(action: {
                            selectedRepository = repo
                        }) {
                            HStack {
                                Text(repo.name)
                                    .font(.caption)
                                    .foregroundColor(selectedRepository?.id == repo.id ? .white : .primary)

                                if let platformIcon = repo.platform.icon {
                                    Image(systemName: platformIcon)
                                        .font(.caption2)
                                        .foregroundColor(selectedRepository?.id == repo.id ? .white : .secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(selectedRepository?.id == repo.id ? Color.accentColor : Color.gray.opacity(0.2))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Detailed Analytics View
struct DetailedAnalyticsView: View {
    let repository: Repository
    let analytics: RepositoryAnalytics

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(repository.displayName)
                    .font(.headline)

                Spacer()

                HealthScoreBadge(score: analytics.healthScore)

                ActivityBadge(level: analytics.activityLevel)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                MetricCard(
                    title: "Stars",
                    value: "\(analytics.starCount)",
                    change: "+\(analytics.starsGainedToday)",
                    trend: .up,
                    color: .yellow
                )

                MetricCard(
                    title: "Forks",
                    value: "\(analytics.forkCount)",
                    change: nil,
                    trend: nil,
                    color: .purple
                )

                MetricCard(
                    title: "Issues",
                    value: "\(analytics.issueCount)",
                    change: "\(analytics.issuesClosedToday > 0 ? "+\(analytics.issuesClosedToday)" : "\(analytics.issuesOpenedToday)")",
                    trend: analytics.issuesClosedToday > 0 ? .up : analytics.issuesOpenedToday > 0 ? .down : .neutral,
                    color: analytics.issuesClosedToday > 0 ? .green : .red
                )

                MetricCard(
                    title: "PRs",
                    value: "\(analytics.openPullRequestCount)",
                    change: "+\(analytics.pullRequestsMergedToday)",
                    trend: .up,
                    color: .blue
                )

                MetricCard(
                    title: "Commits",
                    value: "\(analytics.commitCount)",
                    change: nil,
                    trend: nil,
                    color: .green
                )

                MetricCard(
                    title: "Contributors",
                    value: "\(analytics.contributorCount)",
                    change: nil,
                    trend: nil,
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Charts Section
struct ChartsSection: View {
    let analytics: [RepositoryAnalytics]
    let selectedTimeRange: AnalyticsDashboardView.TimeRange
    let selectedRepository: Repository?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity Trends")
                .font(.headline)

            // Combined star history
            if !analytics.isEmpty {
                let allStarData = analytics.flatMap { $0.getDailyStarHistory() }
                if !allStarData.isEmpty {
                    LineChart(
                        data: allStarData.map(Double.init),
                        color: .blue,
                        title: "Combined Star History"
                    )
                }
            }

            // Individual repository charts
            if let selectedRepo = selectedRepository,
               let repoAnalytics = analytics.first(where: { $0.repositoryID == selectedRepo.persistentModelID }) {
                VStack(spacing: 16) {
                    BarChart(
                        data: [
                            Double(repoAnalytics.starsGainedToday),
                            Double(repoAnalytics.issuesOpenedToday),
                            Double(repoAnalytics.pullRequestsOpenedToday)
                        ],
                        colors: [.yellow, .red, .blue],
                        title: "Today's Activity"
                    )

                    HStack {
                        ProgressRing(
                            progress: Double(repoAnalytics.healthScore) / 100,
                            color: .green,
                            title: "Health",
                            value: "\(Int(repoAnalytics.healthScore))%"
                        )

                        ProgressRing(
                            progress: min(Double(repoAnalytics.contributorCount) / 10, 1.0),
                            color: .orange,
                            title: "Contributors",
                            value: "\(repoAnalytics.contributorCount)"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Pro Upgrade Card
struct ProUpgradeCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)

                Text("Unlock Advanced Analytics")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }

            Text("Get Pro to access detailed repository analytics, custom reports, and team insights.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Upgrade to Pro") {
                // This would open the paywall
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(8)
    }
}

// MARK: - Badge Components
struct HealthScoreBadge: View {
    let score: Double

    var body: some View {
        Text("\(Int(score))%")
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(healthColor.opacity(0.2))
            )
            .foregroundColor(healthColor)
    }

    private var healthColor: Color {
        switch score {
        case 80...100: return .green
        case 60..<80: return .yellow
        case 40..<60: return .orange
        default: return .red
        }
    }
}

struct ActivityBadge: View {
    let level: RepositoryAnalytics.ActivityLevel

    var body: some View {
        Text(level.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(activityColor.opacity(0.2))
            )
            .foregroundColor(activityColor)
    }

    private var activityColor: Color {
        switch level {
        case .veryLow: return .gray
        case .low: return .blue
        case .moderate: return .green
        case .high: return .orange
        case .veryHigh: return .red
        }
    }
}

// MARK: - Previews
#Preview {
    AnalyticsDashboardView()
        .frame(width: 800, height: 600)
}