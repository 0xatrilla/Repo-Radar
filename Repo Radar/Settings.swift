//
//  Settings.swift
//  Repo Radar
//
//  Created by Callum Matthews on 20/09/2025.
//

import Foundation
import Combine
import ServiceManagement

class Settings: ObservableObject {
    static let shared = Settings()

    @Published var refreshInterval: TimeInterval {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval")
        }
    }

    @Published var personalAccessToken: String? {
        didSet {
            UserDefaults.standard.set(personalAccessToken, forKey: "personalAccessToken")
        }
    }

    @Published var notificationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        }
    }

    // Granular notification preferences
    @Published var notifyOnRelease: Bool {
        didSet { UserDefaults.standard.set(notifyOnRelease, forKey: "notifyOnRelease") }
    }

    @Published var notifyOnStar: Bool {
        didSet { UserDefaults.standard.set(notifyOnStar, forKey: "notifyOnStar") }
    }

    @Published var notifyOnIssue: Bool {
        didSet { UserDefaults.standard.set(notifyOnIssue, forKey: "notifyOnIssue") }
    }

    // Launch at login
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin()
        }
    }

    private init() {
        // Default refresh interval: 15 minutes
        self.refreshInterval = UserDefaults.standard.double(forKey: "refreshInterval") > 0
            ? UserDefaults.standard.double(forKey: "refreshInterval")
            : 900 // 15 minutes in seconds

        self.personalAccessToken = UserDefaults.standard.string(forKey: "personalAccessToken")

        self.notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        // Default to true if not set
        if UserDefaults.standard.object(forKey: "notificationsEnabled") == nil {
            self.notificationsEnabled = true
        }

        // Granular notifications (default: all on)
        if UserDefaults.standard.object(forKey: "notifyOnRelease") == nil { UserDefaults.standard.set(true, forKey: "notifyOnRelease") }
        if UserDefaults.standard.object(forKey: "notifyOnStar") == nil { UserDefaults.standard.set(true, forKey: "notifyOnStar") }
        if UserDefaults.standard.object(forKey: "notifyOnIssue") == nil { UserDefaults.standard.set(true, forKey: "notifyOnIssue") }
        self.notifyOnRelease = UserDefaults.standard.bool(forKey: "notifyOnRelease")
        self.notifyOnStar = UserDefaults.standard.bool(forKey: "notifyOnStar")
        self.notifyOnIssue = UserDefaults.standard.bool(forKey: "notifyOnIssue")

        // Launch at login (default off)
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")
        // Apply cached preference on start
        applyLaunchAtLogin()
    }

    private func applyLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Launch at login change failed: \(error.localizedDescription)")
            }
        }
    }
}

