//
//  ProManager.swift
//  Repo Radar
//
//  Created by Assistant on 20/09/2025.
//

import Foundation
import StoreKit
import Combine

@MainActor
final class ProManager: ObservableObject {
    static let shared = ProManager()

    // Update this to your real product identifier in App Store Connect
    static let monthlyProductId = "com.reporadar.pro.monthly"

    @Published private(set) var isSubscribed: Bool = UserDefaults.standard.bool(forKey: "isSubscribed")
    @Published private(set) var isPurchasing: Bool = false

    private init() {
        Task { await refreshEntitlements() }
    }

    func refreshEntitlements() async {
        // Read current entitlements and update local state
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let txn) = result, txn.productID == Self.monthlyProductId {
                active = true
                break
            }
        }
        setSubscribed(active)
    }

    func purchasePro() async throws {
        isPurchasing = true
        defer { isPurchasing = false }

        let products = try await Product.products(for: [Self.monthlyProductId])
        guard let product = products.first else { throw PurchaseError.productNotFound }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification {
                await transaction.finish()
                setSubscribed(true)
            } else {
                throw PurchaseError.verificationFailed
            }
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    private func setSubscribed(_ value: Bool) {
        isSubscribed = value
        UserDefaults.standard.set(value, forKey: "isSubscribed")
    }

    enum PurchaseError: Error {
        case productNotFound
        case verificationFailed
    }
}


