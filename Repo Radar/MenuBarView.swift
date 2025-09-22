//
//  MenuBarView.swift
//  Repo Radar
//
//  Created by Callum Matthews on 20/09/2025.
//

import SwiftUI
import AppKit

// Simple theme model & picker (Pro unlocks)
enum AppTheme: String, CaseIterable, Identifiable {
    case system, blue, green, purple, orange, skyGradient, sunsetGradient, auroraGradient, oceanGradient, fireGradient, forestGradient
    var id: String { rawValue }
}

struct ThemePicker: View {
    @AppStorage("appTheme") private var themeRaw: String = AppTheme.system.rawValue
    private var theme: AppTheme { AppTheme(rawValue: themeRaw) ?? .system }

    var body: some View {
        Picker("Theme", selection: Binding(
            get: { theme },
            set: { themeRaw = $0.rawValue }
        )) {
            ForEach(AppTheme.allCases) { t in
                Text(t.rawValue.capitalized).tag(t)
            }
        }
        .pickerStyle(.menu)
    }
}

// Simple palette helper
private func themeAccent(_ theme: AppTheme) -> Color {
    switch theme {
    case .system: return .accentColor
    case .blue: return .blue
    case .green: return .green
    case .purple: return .purple
    case .orange: return .orange
    case .skyGradient, .sunsetGradient, .auroraGradient, .oceanGradient, .fireGradient, .forestGradient:
        // For gradient themes, return a representative color for compatibility
        // The actual gradient rendering happens elsewhere with themeGradient()
        switch theme {
        case .skyGradient: return .cyan
        case .sunsetGradient: return .orange
        case .auroraGradient: return .purple
        case .oceanGradient: return .teal
        case .fireGradient: return .red
        case .forestGradient: return .green
        default: return .accentColor
        }
    }
}

// For gradient themes, provide a background modifier
private func themeGradient(_ theme: AppTheme) -> LinearGradient? {
    switch theme {
    case .skyGradient:
        return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
    case .sunsetGradient:
        return LinearGradient(colors: [.pink, .orange], startPoint: .leading, endPoint: .trailing)
    case .auroraGradient:
        return LinearGradient(colors: [.green, .purple], startPoint: .leading, endPoint: .trailing)
    case .oceanGradient:
        return LinearGradient(colors: [.blue, .teal, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    case .fireGradient:
        return LinearGradient(colors: [.red, .orange, .yellow], startPoint: .bottomLeading, endPoint: .topTrailing)
    case .forestGradient:
        return LinearGradient(colors: [.green, .mint, .teal], startPoint: .bottomTrailing, endPoint: .topLeading)
    default:
        return nil
    }
}

// Helper to apply gradient to text for gradient themes
private func gradientText(_ text: String, theme: AppTheme, font: Font) -> some View {
    Group {
        if let gradient = themeGradient(theme) {
            Text(text)
                .font(font)
                .overlay(
                    gradient
                        .mask(Text(text).font(font))
                )
                .foregroundColor(.clear)
        } else {
            Text(text)
                .font(font)
                .foregroundColor(themeAccent(theme))
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var viewModel: RepoRadarViewModel
    @Environment(\.openWindow) private var openWindow
    @State private var showingAddRepo = false
    @State private var newRepoInput = ""
    @State private var inlineAddOpen = false
    @State private var showingImport = false // legacy (sheet removed)

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Repo Radar")
                    .font(.headline)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Add Repository Button
            Button(action: {
                print("Add Repository button clicked")
                inlineAddOpen = true
            }) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Repository")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Inline Add Row
            if inlineAddOpen {
                InlineAddRow(viewModel: viewModel, isOpen: $inlineAddOpen)
                Divider()
            }

            // Repository List
            if viewModel.repositories.isEmpty {
                VStack {
                    Image(systemName: "star.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                        .padding(.bottom, 8)
                    Text("No repositories")
                        .font(.headline)
                    Text("Add a repository to start tracking")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.repositories) { repo in
                            RepositoryRow(repository: repo, viewModel: viewModel)
                            Divider()
                        }
                    }
                }
                .frame(maxWidth: 380, maxHeight: 520)
            }

            // Footer
            VStack(spacing: 4) {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }

                HStack {
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        HStack {
                            Image(systemName: "power")
                            Text("Quit")
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: { Task { await viewModel.refreshRepositories() } }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Refresh")
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isLoading)

                    Spacer()

                    Button(action: {
                        if Settings.shared.personalAccessToken?.isEmpty == false {
                            NSApplication.shared.activate(ignoringOtherApps: true)
                            openWindow(id: "import")
                            bringWindowToFront(title: "Import My Repos")
                        } else {
                            NSApplication.shared.activate(ignoringOtherApps: true)
                            openWindow(id: "settings")
                            bringWindowToFront(title: "Settings")
                        }
                    }) {
                        HStack {
                            Image(systemName: "tray.and.arrow.down")
                            Text("Import My Repos")
                        }
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        openWindow(id: "settings")
                        bringWindowToFront(title: "Settings")
                    }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 380)
        // Import presented as dedicated window now
    }
}

// MARK: - Window helpers
private func bringWindowToFront(title: String) {
    NSApplication.shared.windows.first(where: { $0.title == title })?.makeKeyAndOrderFront(nil)
}

struct RepositoryRow: View {
    let repository: Repository
    let viewModel: RepoRadarViewModel
    @State private var isHovered = false
    @State private var expanded = false

    var body: some View {
        let selectedTheme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? AppTheme.system.rawValue) ?? .system
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                Text(repository.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let releaseTag = repository.latestReleaseTag {
                        gradientText(releaseTag, theme: selectedTheme, font: .system(size: 11))
                            .lineLimit(1)
                    } else {
                        Text("No releases")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
                }

                Spacer()

                // Star count badge
                gradientText("★ \(repository.starCount)", theme: selectedTheme, font: .system(size: 12, weight: .semibold))

                Text("More")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.gray)

                Image(systemName: expanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .opacity(isHovered ? 1.0 : 0.5)
            }
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 6) {
                    if let tag = repository.latestReleaseTag, let date = repository.latestReleaseDate {
                        HStack(spacing: 8) {
                            Text("Latest release:")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            gradientText(tag, theme: selectedTheme, font: .system(size: 11))
                            Text(date, style: .date)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        .onTapGesture {
                            if let url = URL(string: "https://github.com/\(repository.displayName)/releases") { NSWorkspace.shared.open(url) }
                        }
                    }

                    if let issueTitle = repository.latestIssueTitle, let issueDate = repository.latestIssueDate {
                        HStack(spacing: 8) {
                            Text("Latest issue:")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            gradientText(issueTitle, theme: selectedTheme, font: .system(size: 11))
                                .lineLimit(1)
                            Text(issueDate, style: .relative)
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        .onTapGesture {
                            if let url = URL(string: "https://github.com/\(repository.displayName)/issues") { NSWorkspace.shared.open(url) }
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Open Repo") {
                            if let url = URL(string: repository.url) { NSWorkspace.shared.open(url) }
                        }
                        .buttonStyle(.link)

                        Button("Stars") {
                            if let url = URL(string: "https://github.com/\(repository.displayName)/stargazers") { NSWorkspace.shared.open(url) }
                        }
                        .buttonStyle(.link)

                        Button("Releases") {
                            if let url = URL(string: "https://github.com/\(repository.displayName)/releases") { NSWorkspace.shared.open(url) }
                        }
                        .buttonStyle(.link)

                        Button("Issues") {
                            if let url = URL(string: "https://github.com/\(repository.displayName)/issues") { NSWorkspace.shared.open(url) }
                        }
                        .buttonStyle(.link)

                        Spacer()

                        Button("Remove") {
                            viewModel.removeRepository(repository)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? Color.gray.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Open Repository") {
                if let url = URL(string: repository.url) {
                    NSWorkspace.shared.open(url)
                }
            }

            Button("Copy URL") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(repository.url, forType: .string)
            }

            Divider()

            Button("Remove Repository") {
                viewModel.removeRepository(repository)
            }
        }
    }
}

struct InlineAddRow: View {
    @ObservedObject var viewModel: RepoRadarViewModel
    @Binding var isOpen: Bool
    @State private var input = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            TextField("owner/repo or GitHub URL", text: $input)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isInputFocused)
                .onSubmit { addRepository() }

            Button("Add") { addRepository() }
                .disabled(input.isEmpty || viewModel.isLoading)

            Button("Cancel") { isOpen = false }
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear { isInputFocused = true }
    }

    private func addRepository() {
        guard !input.isEmpty else { return }

        Task {
            await viewModel.addRepository(from: input)
            if viewModel.errorMessage == nil {
                isOpen = false
                input = ""
            }
        }
    }
}

struct SettingsSheet: View {
    @StateObject private var settings = Settings.shared
    @Binding var isPresented: Bool
    @State private var verifyMessage: String?
    @State private var verifying = false
    private let service = GitHubService()
    @ObservedObject private var pro = ProManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                if !pro.isSubscribed {
                    Button(pro.isPurchasing ? "Purchasing…" : "Get Pro") {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        openWindow(id: "pro")
                        bringWindowToFront(title: "Get Pro")
                    }
                    .disabled(pro.isPurchasing)
                }
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }

            VStack(alignment: .leading, spacing: 16) {
                // Refresh Interval
                VStack(alignment: .leading, spacing: 8) {
                    Text("Refresh Interval")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Picker("Refresh every", selection: $settings.refreshInterval) {
                        Text("5 minutes").tag(300.0)
                        Text("15 minutes").tag(900.0)
                        Text("30 minutes").tag(1800.0)
                        Text("1 hour").tag(3600.0)
                        Text("2 hours").tag(7200.0)
                    }
                    .pickerStyle(.menu)
                }

                // Notifications
                Toggle("Enable Notifications", isOn: $settings.notificationsEnabled)
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Releases", isOn: $settings.notifyOnRelease)
                    Toggle("Stars", isOn: $settings.notifyOnStar)
                    Toggle("Issues", isOn: $settings.notifyOnIssue)
                }
                .padding(.leading, 18)

                Divider()

                // Personal Access Token
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Personal Access Token (Optional)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Button("Create PAT…") {
                            if let url = URL(string: "https://github.com/settings/tokens?type=beta") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }

                    SecureField("GitHub Personal Access Token", text: Binding(
                        get: { settings.personalAccessToken ?? "" },
                        set: { settings.personalAccessToken = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text("Optional: Add a GitHub Personal Access Token to avoid rate limiting. Token only needs 'repo' scope.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button(verifying ? "Verifying…" : "Save & Verify") {
                            Task { await saveAndVerify() }
                        }
                        .disabled(verifying)

                        if let verifyMessage = verifyMessage {
                            Text(verifyMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Divider()

                // Launch at login
                Toggle("Launch at login", isOn: $settings.launchAtLogin)

                // Restore purchases
                if !pro.isSubscribed {
                    Button("Restore Purchases") { Task { try? await pro.restorePurchases() } }
                        .buttonStyle(.link)
                }

                Divider()

                // Legal Links
                VStack(alignment: .leading, spacing: 8) {
                    Text("Legal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 16) {
                        Button("Terms of Use") {
                            if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                        
                        Button("Privacy Policy") {
                            if let url = URL(string: "https://github.com/0xatrilla/Repo-Radar/blob/main/PRIVACY_POLICY.md") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }

                Divider()

                // Themes (Pro)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Theme")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if !pro.isSubscribed {
                            Text("Pro")
                                .font(.caption2)
                                .padding(4)
                                .background(Color.yellow.opacity(0.3))
                                .cornerRadius(4)
                        }
                    }
                    ThemePicker()
                        .disabled(!pro.isSubscribed)
                        .opacity(pro.isSubscribed ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .frame(width: 420, height: 320)
    }

    private func saveAndVerify() async {
        verifying = true
        verifyMessage = nil
        service.setPersonalAccessToken(settings.personalAccessToken)
        do {
            let user = try await service.verifyToken()
            verifyMessage = "Token verified for @\(user)"
        } catch GitHubError.invalidToken {
            verifyMessage = "Invalid token"
        } catch GitHubError.rateLimited {
            verifyMessage = "Rate limited; try later"
        } catch {
            verifyMessage = error.localizedDescription
        }
        verifying = false
    }
}

struct SettingsWindowView: View {
    @StateObject private var settings = Settings.shared
    @State private var verifyMessage: String?
    @State private var verifying = false
    private let service = GitHubService()
    @ObservedObject private var pro = ProManager.shared
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Settings").font(.headline)
                Spacer()
                if !pro.isSubscribed {
                    Button(pro.isPurchasing ? "Purchasing…" : "Get Pro") {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                        openWindow(id: "pro")
                        bringWindowToFront(title: "Get Pro")
                    }
                    .disabled(pro.isPurchasing)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Refresh Interval").font(.subheadline).fontWeight(.medium)
                    Picker("Refresh every", selection: $settings.refreshInterval) {
                        Text("5 minutes").tag(300.0)
                        Text("15 minutes").tag(900.0)
                        Text("30 minutes").tag(1800.0)
                        Text("1 hour").tag(3600.0)
                        Text("2 hours").tag(7200.0)
                    }
                    .pickerStyle(.menu)
                }

                Toggle("Enable Notifications", isOn: $settings.notificationsEnabled)
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Releases", isOn: $settings.notifyOnRelease)
                    Toggle("Stars", isOn: $settings.notifyOnStar)
                    Toggle("Issues", isOn: $settings.notifyOnIssue)
                }
                .padding(.leading, 18)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Personal Access Token (Optional)").font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Button("Create PAT…") {
                            if let url = URL(string: "https://github.com/settings/tokens?type=beta") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }

                    SecureField("GitHub Personal Access Token", text: Binding(
                        get: { settings.personalAccessToken ?? "" },
                        set: { settings.personalAccessToken = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text("Optional: Add a GitHub Personal Access Token to avoid rate limiting. Token needs 'repo' scope.")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        Button(verifying ? "Verifying…" : "Save & Verify") {
                            Task { await saveAndVerify() }
                        }
                        .disabled(verifying)

                        if let verifyMessage = verifyMessage {
                            Text(verifyMessage)
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                }

                Divider()

                Toggle("Launch at login", isOn: $settings.launchAtLogin)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Theme").font(.subheadline).fontWeight(.medium)
                        if !pro.isSubscribed {
                            Text("Pro").font(.caption2)
                                .padding(4)
                                .background(Color.yellow.opacity(0.3))
                                .cornerRadius(4)
                        }
                    }
                    ThemePicker()
                        .disabled(!pro.isSubscribed)
                        .opacity(pro.isSubscribed ? 1.0 : 0.5)
                }

                if !pro.isSubscribed {
                    Button("Restore Purchases") { Task { try? await pro.restorePurchases() } }
                        .buttonStyle(.link)
                }

                Divider()

                // Legal Links
                VStack(alignment: .leading, spacing: 8) {
                    Text("Legal")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 16) {
                        Button("Terms of Use") {
                            if let url = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                        
                        Button("Privacy Policy") {
                            if let url = URL(string: "https://github.com/0xatrilla/Repo-Radar/blob/main/PRIVACY_POLICY.md") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }

    private func saveAndVerify() async {
        verifying = true
        verifyMessage = nil
        let token = settings.personalAccessToken
        service.setPersonalAccessToken(token)
        do {
            let user = try await service.verifyToken()
            verifyMessage = "Token verified for @\(user)"
        } catch GitHubError.invalidToken {
            verifyMessage = "Invalid token"
        } catch GitHubError.rateLimited {
            verifyMessage = "Rate limited; try later"
        } catch {
            verifyMessage = error.localizedDescription
        }
        verifying = false
    }
}

struct ImportMyReposView: View {
    @ObservedObject var viewModel: RepoRadarViewModel
    @Binding var isPresented: Bool
    @State private var repos: [GitHubService.UserRepoSummary] = []
    @State private var selected: Set<Int> = []
    @State private var search = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var filtered: [GitHubService.UserRepoSummary] {
        if search.isEmpty { return repos }
        return repos.filter { $0.fullName.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Import My Repos")
                    .font(.headline)
                Spacer()
                Button("Cancel") { isPresented = false }
            }

            TextField("Search", text: $search)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.08))
                    .opacity(0) // keep background transparent but reserve space
                if isLoading {
                    HStack { ProgressView(); Text("Loading...") }
                        .padding(.top, 8)
                } else if let errorMessage = errorMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(errorMessage).foregroundColor(.red)
                        Button("Retry") { Task { await load() } }
                    }
                    .padding(.top, 8)
                } else {
                    if filtered.isEmpty {
                        Text("No repositories found")
                            .foregroundColor(.gray)
                            .padding(.top, 8)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                ForEach(filtered, id: \.id) { repo in
                                    HStack {
                                        Toggle(isOn: Binding(
                                            get: { selected.contains(repo.id) },
                                            set: { newVal in
                                                if newVal { selected.insert(repo.id) } else { selected.remove(repo.id) }
                                            }
                                        )) { EmptyView() }
                                        .toggleStyle(.checkbox)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(repo.fullName)
                                                .font(.system(size: 12, weight: .medium))
                                            Text("★ \(repo.stargazersCount)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        Button("Open") {
                                            if let url = URL(string: repo.htmlUrl) { NSWorkspace.shared.open(url) }
                                        }
                                        .buttonStyle(.link)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
            .frame(height: 320)
            
            HStack {
                Spacer()
                Button("Import (\(selected.count))") {
                    Task { await importSelected() }
                }
                .disabled(selected.isEmpty)
            }
        }
        .padding()
        .frame(width: 480)
        .task { await load() }
        .onAppear { Task { await load() } }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            repos = try await viewModel.listMyRepos()
        } catch GitHubError.invalidToken {
            errorMessage = "Invalid Personal Access Token."
        } catch GitHubError.rateLimited {
            errorMessage = "Rate limited. Add/refresh your PAT in Settings."
        } catch let e {
            errorMessage = e.localizedDescription
        }
    }

    private func importSelected() async {
        let toImport = repos.filter { selected.contains($0.id) }
        for repo in toImport {
            let owner = repo.owner.login
            let name = repo.name
            await viewModel.addRepository(from: "\(owner)/\(name)")
        }
        isPresented = false
    }
}

// Window wrapper so ImportMyReposView can be shown in a Window scene
struct ImportMyReposWindow: View {
    let viewModel: RepoRadarViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var isPresented = true

    var body: some View {
        ImportMyReposView(viewModel: viewModel, isPresented: $isPresented)
            .onChange(of: isPresented) { _, newValue in
                if newValue == false { dismiss() }
            }
    }
}
