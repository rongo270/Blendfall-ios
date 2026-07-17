//
//  Store.swift
//  Blendfall
//
//  StoreKit 2 wiring for Blendfall's products, all with no ads in any version:
//   - com.rongo.blendfall.premium ($4.99, non-consumable): levels 151-300,
//     Neon/Sunset/Ocean themes, Circle/Diamond shapes
//   - com.rongo.blendfall.pack.candy / .nature / .retro ($1.99 each,
//     non-consumable): a theme pair + two shapes each
//   - com.rongo.blendfall.hints50 ($0.99, consumable): +50 hints per purchase
//
//  The same identifiers must be created in App Store Connect before release.
//  For local testing, select Blendfall/Products.storekit as the scheme's
//  StoreKit configuration. Entitlements land in ProgressStore so the rest of
//  the app only ever reads one source of truth.
//

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class StoreManager {

    static let premiumID = "com.rongo.blendfall.premium"
    static let hintsID = "com.rongo.blendfall.hints50"

    /// packId ("candy"/"nature"/"retro") -> product id.
    static func packProduct(_ packId: String) -> String { "com.rongo.blendfall.pack.\(packId)" }

    static var allIDs: [String] {
        [premiumID, hintsID] + ProgressStore.packIds.map(packProduct)
    }

    private let progress: ProgressStore

    private(set) var products: [String: Product] = [:]
    /// True when the product list could not be fetched (no network / products not set up yet).
    private(set) var loadFailed = false
    private(set) var purchasing = false

    /// productId -> localized price, e.g. "$4.99".
    var prices: [String: String] {
        products.mapValues(\.displayPrice)
    }

    var available: Bool { !products.isEmpty }

    /// Purchases work when the store loaded, or in DEBUG builds (granted directly,
    /// like the Android debug fallback) so everything can be previewed.
    var canBuy: Bool {
        #if DEBUG
        return true
        #else
        return available
        #endif
    }

    init(progress: ProgressStore) {
        self.progress = progress
        // App-lifetime listener; the store is created once at the root and never deallocated.
        Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        Task { await refresh() }
    }

    // MARK: StoreKit

    func refresh() async {
        do {
            let loaded = try await Product.products(for: Self.allIDs)
            products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
            loadFailed = loaded.isEmpty
        } catch {
            loadFailed = true
        }
        await syncEntitlements()
    }

    func buy(_ productId: String) async {
        guard let product = products[productId] else {
            #if DEBUG
            // No store on this simulator/sideload — grant directly so flows can be tested.
            grant(productId)
            #endif
            return
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            if case .success(let verification) = result,
               case .verified(let transaction) = verification {
                grant(transaction.productID)
                await transaction.finish()
            }
        } catch {
            // Cancelled or failed — the paywall simply stays up.
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await syncEntitlements()
    }

    private func syncEntitlements() async {
        for await entitlement in Transaction.currentEntitlements {
            if case .verified(let transaction) = entitlement, transaction.revocationDate == nil {
                // Consumables never appear here; entitlements are premium + packs.
                grant(transaction.productID, consumables: false)
            }
        }
    }

    private func handle(_ update: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = update else { return }
        if transaction.revocationDate == nil {
            grant(transaction.productID)
        }
        await transaction.finish()
    }

    private func grant(_ productId: String, consumables: Bool = true) {
        switch productId {
        case Self.premiumID:
            progress.setPremium(true)
        case Self.hintsID:
            if consumables { progress.addHints() }
        default:
            if let packId = ProgressStore.packIds.first(where: { Self.packProduct($0) == productId }) {
                progress.setPack(packId, true)
            }
        }
    }
}
