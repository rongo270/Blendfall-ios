//
//  ProgressStore.swift
//  Blendfall
//
//  Saved progress and preferences, backed by UserDefaults — the port of the
//  Android ProgressRepository (DataStore). Same key names, same semantics.
//

import Foundation
import Observation

@Observable
final class ProgressStore {

    /// Every install starts with this many hints.
    static let startingHints = 30

    /// Each purchased refill adds this many hints.
    static let hintsPerRefill = 50

    static let packIds = ["candy", "nature", "retro"]

    // ---------------------------------------------------------------------
    // Development switch: Premium and all three theme packs are granted, so
    // every theme, block shape and premium chapter is available without paying.
    //
    // It is ANDed with the #if DEBUG check below, so leaving it switched on can
    // never ship an unlocked game to the App Store — a release build locks up
    // again by itself. Granted in memory only, so it never writes an entitlement
    // into saved progress that would outlive the debug build.
    //
    // The level gates have their own twin of this switch: `Levels.unlockAll`.
    // ---------------------------------------------------------------------
    static let unlockAllStore = true

    private let defaults = UserDefaults.standard

    private(set) var premium: Bool
    /// packId ("candy"/"nature"/"retro") -> owned.
    private(set) var packs: [String: Bool]
    private(set) var theme: AppTheme
    private(set) var shape: BlockShape
    private(set) var colorblind: Bool
    private(set) var haptics: Bool
    private(set) var hints: Int
    private(set) var onboardingDone: Bool
    /// levelId -> stars (absent = unsolved).
    private(set) var stars: [String: Int]
    /// Star Hunt: levelId -> most stars ever swept up there. Read back clamped to what
    /// the board actually holds, so a saved best left over from an older, star-richer
    /// version of a level can never inflate the total past what is collectable today.
    private(set) var pickups: [String: Int]
    /// durationSec -> best blitz score.
    private(set) var blitzBests: [Int: Int]
    /// nil = follow the system language.
    private(set) var languageOverride: Language?

    var language: Language { languageOverride ?? Language.deviceDefault() }
    var strings: Strings { Strings(language) }
    var palette: BlendPalette { theme.palette }

    /// Every content tier the player can use right now (FREE is always in).
    var ownedTiers: Set<Tier> {
        var tiers: Set<Tier> = [.free]
        if premium { tiers.insert(.premium) }
        if packs["candy"] == true { tiers.insert(.candy) }
        if packs["nature"] == true { tiers.insert(.nature) }
        if packs["retro"] == true { tiers.insert(.retro) }
        return tiers
    }

    init() {
        let defaults = UserDefaults.standard
        premium = defaults.bool(forKey: Keys.premium)
        packs = Dictionary(uniqueKeysWithValues: Self.packIds.map {
            ($0, defaults.bool(forKey: Keys.pack($0)))
        })
        theme = AppTheme.fromId(defaults.string(forKey: Keys.theme) ?? "classic")
        shape = BlockShape.fromId(defaults.string(forKey: Keys.shape) ?? "square")
        colorblind = defaults.bool(forKey: Keys.colorblind)
        haptics = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        hints = defaults.object(forKey: Keys.hints) as? Int ?? Self.startingHints
        onboardingDone = defaults.bool(forKey: Keys.onboardingDone)
        stars = (defaults.dictionary(forKey: Keys.stars) as? [String: Int]) ?? [:]
        pickups = (defaults.dictionary(forKey: Keys.pickups) as? [String: Int]) ?? [:]
        let rawBlitz = (defaults.dictionary(forKey: Keys.blitz) as? [String: Int]) ?? [:]
        blitzBests = Dictionary(uniqueKeysWithValues: rawBlitz.compactMap { key, value in
            Int(key).map { ($0, value) }
        })
        if let raw = defaults.string(forKey: Keys.language) {
            languageOverride = Language(rawValue: raw)
        }

        #if DEBUG
        // `unlockAllStore` above, or `BF_PRO=1` (via SIMCTL_CHILD_BF_PRO), grants
        // everything so premium flows can be inspected without a StoreKit
        // configuration. Both are in-memory only.
        if Self.unlockAllStore || ProcessInfo.processInfo.environment["BF_PRO"] != nil {
            premium = true
            packs = Dictionary(uniqueKeysWithValues: Self.packIds.map { ($0, true) })
        }
        #endif
    }

    func setPremium(_ value: Bool) {
        premium = value
        defaults.set(value, forKey: Keys.premium)
    }

    func setPack(_ packId: String, _ value: Bool) {
        packs[packId] = value
        defaults.set(value, forKey: Keys.pack(packId))
    }

    func setTheme(_ value: AppTheme) {
        theme = value
        defaults.set(value.rawValue, forKey: Keys.theme)
    }

    func setShape(_ value: BlockShape) {
        shape = value
        defaults.set(value.rawValue, forKey: Keys.shape)
    }

    func setColorblind(_ value: Bool) {
        colorblind = value
        defaults.set(value, forKey: Keys.colorblind)
    }

    func setHaptics(_ value: Bool) {
        haptics = value
        defaults.set(value, forKey: Keys.haptics)
    }

    func setOnboardingDone() {
        onboardingDone = true
        defaults.set(true, forKey: Keys.onboardingDone)
    }

    func setLanguage(_ value: Language?) {
        languageOverride = value
        if let value {
            defaults.set(value.rawValue, forKey: Keys.language)
        } else {
            defaults.removeObject(forKey: Keys.language)
        }
    }

    func consumeHint() {
        hints = max(0, hints - 1)
        defaults.set(hints, forKey: Keys.hints)
    }

    func addHints(_ amount: Int = ProgressStore.hintsPerRefill) {
        hints += amount
        defaults.set(hints, forKey: Keys.hints)
    }

    func starsFor(_ levelId: String) -> Int { stars[levelId] ?? 0 }

    /// This level's Star Hunt record, capped at what its board actually holds.
    func pickupsFor(_ levelId: String) -> Int {
        min(pickups[levelId] ?? 0, Levels.pickupsIn(Levels.byId(levelId)))
    }

    /// Stars collected across the whole game.
    ///
    /// Deliberately derived from the per-level bests rather than banked as a running
    /// counter: replaying a level you already swept adds nothing, and going back to a
    /// level you half-cleared and sweeping all three moves the total by exactly the ones
    /// you had not found yet. There is no second copy of the record to drift out of step.
    var pickupsCollected: Int {
        Levels.all.reduce(0) { $0 + min(pickups[$1.id] ?? 0, Levels.pickupsIn($1)) }
    }

    func recordWin(_ levelId: String, stars earned: Int, collected: Int = 0) {
        if earned > (stars[levelId] ?? 0) {
            stars[levelId] = earned
            defaults.set(stars, forKey: Keys.stars)
        }
        recordPickups(levelId, collected: collected)
    }

    /// Records a Star Hunt run's stars, keeping only this level's best. Beating your own
    /// record raises it; matching or missing it changes nothing.
    ///
    /// - Returns: how many stars this run added to the player's total (0 if it was not a
    ///   personal best for this level).
    @discardableResult
    func recordPickups(_ levelId: String, collected: Int) -> Int {
        guard collected > 0 else { return 0 }
        let old = pickups[levelId] ?? 0
        let next = max(old, collected)
        guard next > old else { return 0 }
        pickups[levelId] = next
        defaults.set(pickups, forKey: Keys.pickups)
        return next - old
    }

    /// First unsolved playable Classic level, for the Continue button. Master levels are
    /// optional, so a locked star gate never strands Continue — it just moves past them.
    func continueLevelId() -> String {
        let first = Levels.classic.first { level in
            (stars[level.id] ?? 0) == 0
                && Levels.isUnlocked(level, stars: stars, premium: premium)
        }
        return first?.id ?? Levels.classic.first!.id
    }

    /// @discardableResult true when `score` is a new best for this duration.
    @discardableResult
    func recordBlitzScore(durationSec: Int, score: Int) -> Bool {
        guard score > (blitzBests[durationSec] ?? 0) else { return false }
        blitzBests[durationSec] = score
        let dict = Dictionary(uniqueKeysWithValues: blitzBests.map { (String($0.key), $0.value) })
        defaults.set(dict, forKey: Keys.blitz)
        return true
    }

    func debugTogglePremium() {
        let next = !premium
        setPremium(next)
        Self.packIds.forEach { setPack($0, next) }
    }

    private enum Keys {
        static let premium = "premium"
        static let theme = "theme"
        static let shape = "block_shape"
        static let colorblind = "colorblind"
        static let haptics = "haptics"
        static let hints = "hints_left"
        static let onboardingDone = "onboarding_done"
        static let stars = "stars"
        static let pickups = "pickups"
        static let blitz = "blitz_bests"
        static let language = "language"
        static func pack(_ packId: String) -> String { "pack_\(packId)" }
    }
}

let blitzDurations = [60, 180, 300]
