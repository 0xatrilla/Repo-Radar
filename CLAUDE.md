# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Repo Radar** is a native macOS menu bar application built with **Swift 5.9+** and **SwiftUI**. The app monitors GitHub repositories and provides real-time notifications for new releases, stars, and issues. It uses SwiftData for local persistence and StoreKit for in-app purchases.

- **Platform**: macOS 15.0+
- **Architecture**: Model-View (MV) pattern with ObservableObject-based state management
- **Data Persistence**: SwiftData for local repository storage
- **Networking**: URLSession with async/await for GitHub API integration
- **UI Framework**: SwiftUI with MenuBarExtra for menu bar integration
- **Testing**: XCTest framework (minimal test coverage currently)

## Project Structure

The project follows a traditional Xcode project structure (not Swift Package Manager):

```
Repo Radar/
├── Repo Radar.xcodeproj/          # Xcode project file
├── Repo Radar/                    # Main app target
│   ├── Assets.xcassets/          # Images, colors, app icon
│   ├── Item.swift                 # Repository data model (SwiftData)
│   ├── GitHubService.swift       # GitHub API client
│   ├── RepoRadarViewModel.swift   # Main app state management
│   ├── MenuBarView.swift         # Menu bar UI
│   ├── Settings.swift            # Settings window
│   ├── ContentView.swift         # Main content view
│   ├── ProManager.swift          # StoreKit subscription management
│   ├── ProPaywallView.swift      # Pro subscription UI
│   ├── Repo_RadarApp.swift       # App entry point and window setup
│   └── Repo_Radar.entitlements   # App sandbox entitlements
├── Repo RadarTests/              # Unit tests
└── Repo RadarUITests/            # UI automation tests
```

## Key Components

### Core Architecture
- **App Entry**: `Repo_RadarApp.swift` - Sets up MenuBarExtra, windows, and SwiftData container
- **Data Model**: `Item.swift` - SwiftData model for Repository with GitHub API data
- **API Service**: `GitHubService.swift` - Handles all GitHub API interactions with proper error handling
- **State Management**: `RepoRadarViewModel.swift` - Central ObservableObject for app state

### GitHub Integration
- Uses GitHub REST API with proper authentication headers
- Supports Personal Access Token for higher rate limits
- Handles rate limiting, authentication errors, and network failures
- Fetches repository info, releases, and issues
- Implements proper error types with localized descriptions

### Data Persistence
- SwiftData model for Repository with full CRUD operations
- Stores repository metadata, star counts, release info, and notification preferences
- Automatic background updates and polling
- Tracks star deltas and new releases for notifications

### UI Architecture
- **MenuBarExtra**: Primary interface in menu bar
- **Windows**: Settings, Import My Repos, and Pro Paywall as separate windows
- **SwiftUI Views**: All UI built with SwiftUI, leveraging modern patterns
- **State Flow**: Uses @StateObject, @EnvironmentObject, and @Binding for data flow

## Development Commands

### Building and Running
```bash
# Build the project
xcodebuild -project "Repo Radar.xcodeproj" -scheme "Repo Radar" -configuration Debug build

# Run on current Mac
open "Repo Radar.xcodeproj"
# Then click Run in Xcode

# Build for release
xcodebuild -project "Repo Radar.xcodeproj" -scheme "Repo Radar" -configuration Release build
```

### Testing
```bash
# Run unit tests
xcodebuild -project "Repo Radar.xcodeproj" -scheme "Repo Radar" -destination 'platform=macOS' test

# Run UI tests
xcodebuild -project "Repo Radar.xcodeproj" -scheme "Repo Radar" -destination 'platform=macOS' test
```

### Code Quality
```bash
# Format code (if using SwiftFormat)
swiftformat .

# Lint code (if using SwiftLint)
swiftlint lint
```

## Architecture Guidelines

### State Management
- Use `@ObservableObject` for shared app state (RepoRadarViewModel, ProManager)
- Use `@State` for local view state
- Use `@EnvironmentObject` for dependency injection across views
- Avoid @StateObject in view bodies - initialize in parent or app entry

### Data Flow
- Single source of truth in RepoRadarViewModel
- Views subscribe to state changes via @ObservedObject/@EnvironmentObject
- Actions flow up through closures or direct method calls
- Use async/await for all asynchronous operations

### API Patterns
- All GitHub API calls use async/await with proper error handling
- Use typed errors (GitHubError enum) with localized descriptions
- Implement proper retry logic for rate limiting
- Cache responses appropriately to minimize API calls

### SwiftUI Best Practices
- Extract reusable components into separate views
- Use view modifiers for common styling
- Implement proper previews for all views
- Handle loading states and empty states explicitly

## Configuration

### App Store Connect
- **Bundle Identifier**: Update in Xcode project settings
- **Product ID**: `com.reporadar.pro.monthly` (update in ProManager.swift)
- **App Store Entitlements**: Configured for sandbox and network access

### GitHub API
- Rate limit: 60 requests/hour unauthenticated, 5,000 with Personal Access Token
- Required scopes: `public_repo` for repository access, `user` for user repos
- API version: Use `X-GitHub-Api-Version: 2022-11-28` header

### Development Notes
- App is sandboxed - requires network client entitlement
- Menu bar icon uses custom image with transparent pixel trimming
- Supports both light and dark appearance
- Implements proper macOS window management behaviors

## Cursor Rules Integration

The project includes Cursor IDE rules that align with these guidelines:

### Modern Swift Development (.cursor/rules/modern-swift.mdc)
- Embrace SwiftUI's declarative nature
- Use built-in property wrappers (@State, @Binding, @ObservableObject)
- Prefer async/await over Combine
- Focus on simplicity and native data flow
- Test business logic in isolation

### Code Quality (.cursor/rules/clean.mdc)
- Maintain consistent formatting (SwiftFormat/SwiftLint if available)
- Remove unused imports and variables
- Ensure proper error handling
- Keep functions focused and single-purpose

## Common Development Tasks

### Adding New GitHub API Features
1. Update `GitHubService.swift` with new API methods
2. Add corresponding error cases to `GitHubError` enum
3. Update `Repository` model in `Item.swift` if new data needed
4. Modify `updateRepository` method to fetch new data
5. Update UI views to display new information

### Modifying UI
1. Create new SwiftUI views in separate files
2. Update state management in `RepoRadarViewModel`
3. Add new windows to `Repo_RadarApp.swift` if needed
4. Implement proper previews and accessibility

### Database Changes
1. Modify `Repository` model in `Item.swift`
2. Add migration logic if needed (SwiftData handles simple migrations)
3. Update UI to reflect new data structure
4. Test with existing data to ensure compatibility

## Testing Strategy

Currently minimal test coverage exists. When adding tests:

1. Unit test GitHubService methods with mock data
2. Test Repository model business logic
3. Test ProManager subscription logic
4. Use SwiftUI Previews for visual testing
5. Consider adding UI tests for critical user flows

# Modern Swift Development

Write idiomatic SwiftUI code following Apple's latest architectural recommendations and best practices.

## Core Philosophy

- SwiftUI is the default UI paradigm for Apple platforms - embrace its declarative nature
- Avoid legacy UIKit patterns and unnecessary abstractions
- Focus on simplicity, clarity, and native data flow
- Let SwiftUI handle the complexity - don't fight the framework

## Architecture Guidelines

### 1. Embrace Native State Management

Use SwiftUI's built-in property wrappers appropriately:
- `@State` - Local, ephemeral view state
- `@Binding` - Two-way data flow between views
- `@Observable` - Shared state (iOS 17+)
- `@ObservableObject` - Legacy shared state (pre-iOS 17)
- `@Environment` - Dependency injection for app-wide concerns

### 2. State Ownership Principles

- Views own their local state unless sharing is required
- State flows down, actions flow up
- Keep state as close to where it's used as possible
- Extract shared state only when multiple views need it

### 3. Modern Async Patterns

- Use `async/await` as the default for asynchronous operations
- Leverage `.task` modifier for lifecycle-aware async work
- Avoid Combine unless absolutely necessary
- Handle errors gracefully with try/catch

### 4. View Composition

- Build UI with small, focused views
- Extract reusable components naturally
- Use view modifiers to encapsulate common styling
- Prefer composition over inheritance

### 5. Code Organization

- Organize by feature, not by type (avoid Views/, Models/, ViewModels/ folders)
- Keep related code together in the same file when appropriate
- Use extensions to organize large files
- Follow Swift naming conventions consistently

## Implementation Patterns

### Simple State Example
```swift
struct CounterView: View {
    @State private var count = 0
    
    var body: some View {
        VStack {
            Text("Count: \(count)")
            Button("Increment") { 
                count += 1 
            }
        }
    }
}
```

### Shared State with @Observable
```swift
@Observable
class UserSession {
    var isAuthenticated = false
    var currentUser: User?
    
    func signIn(user: User) {
        currentUser = user
        isAuthenticated = true
    }
}

struct MyApp: App {
    @State private var session = UserSession()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(session)
        }
    }
}
```

### Async Data Loading
```swift
struct ProfileView: View {
    @State private var profile: Profile?
    @State private var isLoading = false
    @State private var error: Error?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let profile {
                ProfileContent(profile: profile)
            } else if let error {
                ErrorView(error: error)
            }
        }
        .task {
            await loadProfile()
        }
    }
    
    private func loadProfile() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            profile = try await ProfileService.fetch()
        } catch {
            self.error = error
        }
    }
}
```

## Best Practices

### DO:
- Write self-contained views when possible
- Use property wrappers as intended by Apple
- Test logic in isolation, preview UI visually
- Handle loading and error states explicitly
- Keep views focused on presentation
- Use Swift's type system for safety

### DON'T:
- Create ViewModels for every view
- Move state out of views unnecessarily
- Add abstraction layers without clear benefit
- Use Combine for simple async operations
- Fight SwiftUI's update mechanism
- Overcomplicate simple features

## Testing Strategy

- Unit test business logic and data transformations
- Use SwiftUI Previews for visual testing
- Test @Observable classes independently
- Keep tests simple and focused
- Don't sacrifice code clarity for testability

## Modern Swift Features

- Use Swift Concurrency (async/await, actors)
- Leverage Swift 6 data race safety when available
- Utilize property wrappers effectively
- Embrace value types where appropriate
- Use protocols for abstraction, not just for testing

## Summary

Write SwiftUI code that looks and feels like SwiftUI. The framework has matured significantly - trust its patterns and tools. Focus on solving user problems rather than implementing architectural patterns from other platforms.