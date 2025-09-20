//
//  Settings.swift
//  Repo Radar
//
//  Created by Callum Matthews on 20/09/2025.
//

import Foundation
import Combine

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
    }
}

