import CryptoKit
import Foundation

/// Durable, account-scoped storage for FocusGlobe's canonical local state.
///
/// The public API intentionally stays key-based so `AppModel` remains the one
/// canonical owner of settings, profile, progress, history and Solo resume
/// state. Underneath, those domains are committed together inside one versioned
/// snapshot in Application Support. Every mutation is serialized, atomically
/// replaces the primary file and retains one last-known-good backup.
final class PersistenceService {

    enum Key: String, CaseIterable {
        case settings = "fg.settings"
        case progress = "fg.progress"
        case history = "fg.history"
        case isPro = "fg.isPro"
        case resumableJourney = "fg.resumableJourney"
        case profile = "fg.profile"
        case pendingNotificationPrompt = "fg.pendingPostOnboardingNotificationPrompt"
        /// What FocusGlobe has ASKED StoreKit to consider, and when. Never
        /// whether a prompt appeared or a review was left — the system reports
        /// neither. See `ReviewRequestPolicy`.
        case reviewLastAttemptAt = "fg.review.lastAttemptAt"
        case reviewFlightsAtLastAttempt = "fg.review.flightsAtLastAttempt"
        case reviewDidAttemptFirstMilestone = "fg.review.didAttemptFirstMilestone"

        /// Keys that live in `UserDefaults` instead of the account-scoped
        /// snapshot, because what they describe belongs to the DEVICE rather
        /// than to whoever happens to be signed in.
        ///
        /// Three things qualify. An App Store entitlement is granted to an Apple
        /// ID and RevenueCat stays authoritative over it. iOS grants exactly one
        /// chance to ask for notification permission per install — a pending ask
        /// that followed an account into a different profile, or vanished when
        /// one was activated, would be asking about the wrong device. And the
        /// rating-request history is about how often THIS device has been asked:
        /// letting it reset with an account switch would let FocusGlobe ask
        /// twice in a week, which is the one thing the policy exists to prevent.
        ///
        /// All of them are primitives, reached only by `bool`/`double`/`integer`
        /// and their setters; `save`/`load`/`remove` route around the snapshot
        /// for them entirely.
        var isDeviceScoped: Bool {
            switch self {
            case .isPro, .pendingNotificationPrompt,
                 .reviewLastAttemptAt, .reviewFlightsAtLastAttempt,
                 .reviewDidAttemptFirstMilestone: return true
            case .settings, .progress, .history, .resumableJourney, .profile: return false
            }
        }
    }

    private struct PersistedUserState: Codable {
        static let currentSchemaVersion = 3

        var schemaVersion: Int
        var revision: UInt64
        var savedAt: Date
        var settings: Data?
        var progress: Data?
        var history: Data?
        var profile: Data?
        var resumableJourney: Data?

        init(schemaVersion: Int = currentSchemaVersion,
             revision: UInt64 = 0,
             savedAt: Date = Date(),
             settings: Data? = nil,
             progress: Data? = nil,
             history: Data? = nil,
             profile: Data? = nil,
             resumableJourney: Data? = nil) {
            self.schemaVersion = schemaVersion
            self.revision = revision
            self.savedAt = savedAt
            self.settings = settings
            self.progress = progress
            self.history = history
            self.profile = profile
            self.resumableJourney = resumableJourney
        }

        private enum CodingKeys: String, CodingKey {
            case schemaVersion, revision, savedAt, settings, progress, history
            case profile, resumableJourney
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 0
            revision = try c.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0
            savedAt = try c.decodeIfPresent(Date.self, forKey: .savedAt) ?? .distantPast
            settings = try c.decodeIfPresent(Data.self, forKey: .settings)
            progress = try c.decodeIfPresent(Data.self, forKey: .progress)
            history = try c.decodeIfPresent(Data.self, forKey: .history)
            profile = try c.decodeIfPresent(Data.self, forKey: .profile)
            resumableJourney = try c.decodeIfPresent(Data.self, forKey: .resumableJourney)
        }

        var containsUserData: Bool {
            settings != nil || progress != nil || history != nil || profile != nil || resumableJourney != nil
        }

        func payload(for key: Key) -> Data? {
            switch key {
            case .settings: return settings
            case .progress: return progress
            case .history: return history
            case .profile: return profile
            case .resumableJourney: return resumableJourney
            case .isPro, .pendingNotificationPrompt,
                 .reviewLastAttemptAt, .reviewFlightsAtLastAttempt,
                 .reviewDidAttemptFirstMilestone: return nil
            }
        }

        mutating func setPayload(_ data: Data?, for key: Key) {
            switch key {
            case .settings: settings = data
            case .progress: progress = data
            case .history: history = data
            case .profile: profile = data
            case .resumableJourney: resumableJourney = data
            case .isPro, .pendingNotificationPrompt,
                 .reviewLastAttemptAt, .reviewFlightsAtLastAttempt,
                 .reviewDidAttemptFirstMilestone: break
            }
        }
    }

    private enum Account {
        static let anonymous = "anonymous"
    }

    private enum MetadataKey {
        static let anonymousClaimedBy = "fg.persistence.anonymousClaimedBy.v3"
    }

    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let rootURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    private var activeAccountID = Account.anonymous
    private var activeStorageKey: String
    private var state: PersistedUserState

    init(defaults: UserDefaults = .standard,
         fileManager: FileManager = .default,
         rootURL: URL? = nil) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        self.encoder.outputFormatting = [.sortedKeys]
        self.encoder.dateEncodingStrategy = .millisecondsSince1970
        self.decoder.dateDecodingStrategy = .millisecondsSince1970

        if let rootURL {
            self.rootURL = rootURL
        } else {
            let support = (try? fileManager.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true))
                ?? fileManager.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            self.rootURL = support
                .appendingPathComponent("FocusGlobe", isDirectory: true)
                .appendingPathComponent("UserState", isDirectory: true)
        }

        self.activeStorageKey = Self.storageKey(for: Account.anonymous)
        self.state = PersistedUserState()
        try? fileManager.createDirectory(at: self.rootURL,
                                         withIntermediateDirectories: true)

        if let loaded = Self.readState(storageKey: activeStorageKey,
                                       rootURL: self.rootURL,
                                       decoder: decoder) {
            self.state = Self.migrate(loaded.state)
            if loaded.recoveredFromBackup {
                Self.writeRecoveredState(self.state,
                                         storageKey: activeStorageKey,
                                         rootURL: self.rootURL,
                                         encoder: encoder,
                                         fileManager: fileManager)
            }
        } else {
            let legacy = Self.legacyState(from: defaults)
            self.state = Self.migrate(legacy)
            if legacy.containsUserData {
                _ = Self.write(self.state,
                               storageKey: activeStorageKey,
                               rootURL: self.rootURL,
                               encoder: encoder,
                               decoder: decoder,
                               fileManager: fileManager)
                #if DEBUG
                print("[Persistence] Imported legacy local state into the anonymous profile.")
                #endif
            }
        }
    }

    /// Switch the canonical local profile to the authenticated Supabase user.
    /// A first-ever signed account receives the legacy anonymous state exactly
    /// once; subsequent accounts start independently and can never inherit it.
    /// Returns `true` only when the active account actually changed.
    @discardableResult
    func activateAccount(_ stableUserID: String?) -> Bool {
        let accountID = stableUserID?.lowercased() ?? Account.anonymous
        lock.lock()
        defer { lock.unlock() }
        guard accountID != activeAccountID else { return false }

        // All normal mutations are synchronous. Rewriting here is a final
        // lifecycle boundary and guarantees the preceding account is durable
        // before another account can become active.
        _ = writeLocked()

        activeAccountID = accountID
        activeStorageKey = Self.storageKey(for: accountID)

        if let loaded = Self.readState(storageKey: activeStorageKey,
                                       rootURL: rootURL,
                                       decoder: decoder) {
            state = Self.migrate(loaded.state)
            if loaded.recoveredFromBackup {
                Self.writeRecoveredState(state,
                                         storageKey: activeStorageKey,
                                         rootURL: rootURL,
                                         encoder: encoder,
                                         fileManager: fileManager)
            }
        } else if accountID != Account.anonymous,
                  defaults.string(forKey: MetadataKey.anonymousClaimedBy) == nil,
                  let anonymous = Self.readState(storageKey: Self.storageKey(for: Account.anonymous),
                                                 rootURL: rootURL,
                                                 decoder: decoder)?.state,
                  anonymous.containsUserData {
            state = Self.migrate(anonymous)
            state.revision &+= 1
            state.savedAt = Date()
            if writeLocked() {
                // The marker is written only after the copied snapshot is safely
                // committed. A failed write can be retried without duplication.
                defaults.set(activeStorageKey, forKey: MetadataKey.anonymousClaimedBy)
                #if DEBUG
                print("[Persistence] Completed one-time anonymous profile adoption.")
                #endif
            }
        } else {
            state = PersistedUserState()
            _ = writeLocked()
        }

        #if DEBUG
        print("[Persistence] Loaded account-scoped state at schema \(state.schemaVersion), revision \(state.revision).")
        #endif
        return true
    }

    func load<T: Decodable>(_ type: T.Type, for key: Key) -> T? {
        lock.lock()
        let data = state.payload(for: key)
        lock.unlock()
        guard let data else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            #if DEBUG
            print("[Persistence] A stored domain could not be decoded; other domains were preserved.")
            #endif
            return nil
        }
    }

    func save<T: Encodable>(_ value: T, for key: Key) {
        guard !key.isDeviceScoped else { return }
        let data: Data
        do {
            data = try encoder.encode(value)
        } catch {
            #if DEBUG
            print("[Persistence] Encoding failed; the previous durable state was retained.")
            #endif
            return
        }

        lock.lock()
        state.setPayload(data, for: key)
        state.revision &+= 1
        state.savedAt = Date()
        _ = writeLocked()
        lock.unlock()
    }

    /// Commits every canonical user-owned domain as one durable transaction.
    /// Encoding completes before the lock is taken, so an encoding failure
    /// cannot leave a partially-updated snapshot on disk.
    func saveCanonicalState(settings: AppSettings,
                            progress: UserProgress,
                            history: [FocusSessionRecord],
                            profile: UserProfile,
                            resumableJourney: ResumableJourney?) {
        let encodedSettings: Data
        let encodedProgress: Data
        let encodedHistory: Data
        let encodedProfile: Data
        let encodedResume: Data?
        do {
            encodedSettings = try encoder.encode(settings)
            encodedProgress = try encoder.encode(progress)
            encodedHistory = try encoder.encode(history)
            encodedProfile = try encoder.encode(profile)
            encodedResume = try resumableJourney.map { try encoder.encode($0) }
        } catch {
            #if DEBUG
            print("[Persistence] Transaction encoding failed; the previous snapshot was retained.")
            #endif
            return
        }

        lock.lock()
        state.settings = encodedSettings
        state.progress = encodedProgress
        state.history = encodedHistory
        state.profile = encodedProfile
        state.resumableJourney = encodedResume
        state.revision &+= 1
        state.savedAt = Date()
        _ = writeLocked()
        lock.unlock()
    }

    /// Device-scoped flags (see `Key.isDeviceScoped`): the RevenueCat mirror,
    /// which stays authoritative and deliberately independent of the
    /// account-scoped progression snapshot, and the pending post-onboarding
    /// notification ask, which belongs to this install's one permission
    /// opportunity.
    ///
    /// An absent key reads `false`, which is what makes the pending ask safe to
    /// introduce: every pilot who finished onboarding before it existed has no
    /// key, so nothing is ever asked of them.
    func bool(for key: Key) -> Bool {
        defaults.bool(forKey: key.rawValue)
    }

    func setBool(_ value: Bool, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    /// The same device-scoped store as `bool(for:)`, for the two review-attempt
    /// values that are not flags. Kept here rather than as loose `@AppStorage`
    /// in a view so `AppModel` remains the one owner of persisted state — the
    /// rating policy has to be readable in one place to be reasoned about.
    /// Both return the UserDefaults zero (`0`) when never written, which the
    /// policy reads as "never asked".
    func double(for key: Key) -> Double {
        defaults.double(forKey: key.rawValue)
    }

    func setDouble(_ value: Double, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    func integer(for key: Key) -> Int {
        defaults.integer(forKey: key.rawValue)
    }

    func setInteger(_ value: Int, for key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    func remove(_ key: Key) {
        if key.isDeviceScoped {
            defaults.removeObject(forKey: key.rawValue)
            return
        }
        lock.lock()
        state.setPayload(nil, for: key)
        state.revision &+= 1
        state.savedAt = Date()
        _ = writeLocked()
        lock.unlock()
    }

    /// Critical state is written synchronously at mutation time. This explicit
    /// flush is used at lifecycle/account boundaries as an additional durable
    /// checkpoint, never as the primary save mechanism.
    func flush() {
        lock.lock()
        _ = writeLocked()
        lock.unlock()
    }

    /// Wipes FocusGlobe data only from the existing DEBUG reset path.
    func wipeAll() {
        lock.lock()
        try? fileManager.removeItem(at: rootURL)
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        state = PersistedUserState()
        _ = writeLocked()
        lock.unlock()
        Key.allCases.forEach { defaults.removeObject(forKey: $0.rawValue) }
        defaults.removeObject(forKey: MetadataKey.anonymousClaimedBy)
    }

    // MARK: - Atomic storage

    private func writeLocked() -> Bool {
        Self.write(state,
                   storageKey: activeStorageKey,
                   rootURL: rootURL,
                   encoder: encoder,
                   decoder: decoder,
                   fileManager: fileManager)
    }

    private static func primaryURL(storageKey: String, rootURL: URL) -> URL {
        rootURL.appendingPathComponent("\(storageKey).json", isDirectory: false)
    }

    private static func backupURL(storageKey: String, rootURL: URL) -> URL {
        rootURL.appendingPathComponent("\(storageKey).backup.json", isDirectory: false)
    }

    private static func write(_ state: PersistedUserState,
                              storageKey: String,
                              rootURL: URL,
                              encoder: JSONEncoder,
                              decoder: JSONDecoder,
                              fileManager: FileManager) -> Bool {
        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
            let primary = primaryURL(storageKey: storageKey, rootURL: rootURL)
            let backup = backupURL(storageKey: storageKey, rootURL: rootURL)
            if let oldData = try? Data(contentsOf: primary),
               (try? decoder.decode(PersistedUserState.self, from: oldData)) != nil {
                try oldData.write(to: backup, options: [.atomic])
                applyFileProtection(to: backup, fileManager: fileManager)
            }
            let encoded = try encoder.encode(state)
            try encoded.write(to: primary, options: [.atomic])
            applyFileProtection(to: primary, fileManager: fileManager)
            return true
        } catch {
            #if DEBUG
            print("[Persistence] Atomic save failed; the previous snapshot remains available.")
            #endif
            return false
        }
    }

    private static func writeRecoveredState(_ state: PersistedUserState,
                                            storageKey: String,
                                            rootURL: URL,
                                            encoder: JSONEncoder,
                                            fileManager: FileManager) {
        do {
            let data = try encoder.encode(state)
            let primary = primaryURL(storageKey: storageKey, rootURL: rootURL)
            try data.write(to: primary, options: [.atomic])
            applyFileProtection(to: primary, fileManager: fileManager)
            #if DEBUG
            print("[Persistence] Recovered the primary snapshot from its last-known-good backup.")
            #endif
        } catch {
            #if DEBUG
            print("[Persistence] Backup decoded, but restoring the primary file failed.")
            #endif
        }
    }

    private static func applyFileProtection(to url: URL, fileManager: FileManager) {
        #if os(iOS) || os(tvOS) || os(watchOS)
        try? fileManager.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                                       ofItemAtPath: url.path)
        #endif
    }

    private static func readState(storageKey: String,
                                  rootURL: URL,
                                  decoder: JSONDecoder) -> (state: PersistedUserState, recoveredFromBackup: Bool)? {
        let primary = primaryURL(storageKey: storageKey, rootURL: rootURL)
        if let data = try? Data(contentsOf: primary),
           let state = try? decoder.decode(PersistedUserState.self, from: data) {
            return (state, false)
        }
        let backup = backupURL(storageKey: storageKey, rootURL: rootURL)
        if let data = try? Data(contentsOf: backup),
           let state = try? decoder.decode(PersistedUserState.self, from: data) {
            return (state, true)
        }
        return nil
    }

    /// Sequential container migrations. Domain payloads use resilient custom
    /// decoding, so each migration can evolve independently without resetting
    /// unrelated user data.
    private static func migrate(_ source: PersistedUserState) -> PersistedUserState {
        var state = source
        let original = state.schemaVersion
        while state.schemaVersion < PersistedUserState.currentSchemaVersion {
            switch state.schemaVersion {
            case 0:
                // v1 introduced the canonical transaction container.
                state.schemaVersion = 1
            case 1:
                // v2 added profile and Solo-resume domains to that transaction.
                state.schemaVersion = 2
            case 2:
                // v3 introduced stable account scoping and one-time anonymous
                // adoption. No reward/progress mutation is required.
                state.schemaVersion = 3
            default:
                state.schemaVersion = PersistedUserState.currentSchemaVersion
            }
        }
        if original != state.schemaVersion {
            #if DEBUG
            print("[Persistence] Migrated local storage schema \(original) → \(state.schemaVersion).")
            #endif
        }
        return state
    }

    private static func legacyState(from defaults: UserDefaults) -> PersistedUserState {
        PersistedUserState(schemaVersion: 0,
                           settings: defaults.data(forKey: Key.settings.rawValue),
                           progress: defaults.data(forKey: Key.progress.rawValue),
                           history: defaults.data(forKey: Key.history.rawValue),
                           profile: defaults.data(forKey: Key.profile.rawValue),
                           resumableJourney: defaults.data(forKey: Key.resumableJourney.rawValue))
    }

    /// Stable, non-reversible filename token. Raw account identifiers never
    /// appear in paths or diagnostics.
    private static func storageKey(for accountID: String) -> String {
        let digest = SHA256.hash(data: Data("focusglobe:\(accountID)".utf8))
        return digest.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    #if DEBUG
    /// Runs against an isolated temporary store. This protects the release
    /// migration contract without reading or mutating the developer's real
    /// profile: partial legacy decoding, one-time adoption, account isolation,
    /// and backup recovery all execute on every Debug launch.
    static func _selfCheck() -> String? {
        let suiteName = "FocusGlobe.PersistenceRegression.\(UUID().uuidString)"
        guard let testDefaults = UserDefaults(suiteName: suiteName) else {
            return "Could not create isolated UserDefaults suite"
        }
        let testRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: testRoot)
        }

        do {
            // Simulate an older install whose JSON predates most current fields.
            testDefaults.set(Data(#"{"soundEnabled":false}"#.utf8),
                             forKey: Key.settings.rawValue)
            testDefaults.set(Data(#"{"totalFocusMiles":12,"landings":2}"#.utf8),
                             forKey: Key.progress.rawValue)
            testDefaults.set(Data(#"{"hasCompletedOnboarding":true,"lastDailyGiftDay":123}"#.utf8),
                             forKey: Key.profile.rawValue)

            let service = PersistenceService(defaults: testDefaults, rootURL: testRoot)
            guard service.load(AppSettings.self, for: .settings)?.soundEnabled == false,
                  service.load(UserProgress.self, for: .progress)?.totalFocusMiles == 12,
                  service.load(UserProfile.self, for: .profile)?.lastDailyGiftDay == 123 else {
                return "Partial legacy fields did not migrate independently"
            }

            // The first real account adopts anonymous data once.
            service.activateAccount("user-a")
            guard service.load(UserProgress.self, for: .progress)?.totalFocusMiles == 12 else {
                return "First account did not adopt legacy anonymous progress"
            }
            var accountA = UserProgress.empty
            accountA.totalFocusMiles = 111
            service.save(accountA, for: .progress)

            // A second account must begin independently and remain isolated.
            service.activateAccount("user-b")
            guard service.load(UserProgress.self, for: .progress) == nil else {
                return "Second account inherited another account's progress"
            }
            var accountB = UserProgress.empty
            accountB.totalFocusMiles = 222
            service.save(accountB, for: .progress)
            service.activateAccount("user-a")
            guard service.load(UserProgress.self, for: .progress)?.totalFocusMiles == 111 else {
                return "Account A was not restored after switching"
            }
            service.activateAccount("user-b")
            guard service.load(UserProgress.self, for: .progress)?.totalFocusMiles == 222 else {
                return "Account B was not restored after switching"
            }

            // A Daily Gift is a cross-domain economy transaction: the local-day
            // claim marker and the wallet credit must survive together. An
            // account that claimed today must stay ineligible after an update,
            // while another account keeps an independent marker and balance.
            service.activateAccount("user-a")
            accountA.totalFocusMiles = 121
            var accountAProfile = UserProfile.empty
            accountAProfile.lastDailyGiftDay = 7_500
            service.saveCanonicalState(settings: .default,
                                       progress: accountA,
                                       history: [],
                                       profile: accountAProfile,
                                       resumableJourney: nil)
            let relaunchedA = PersistenceService(defaults: testDefaults, rootURL: testRoot)
            relaunchedA.activateAccount("user-a")
            guard relaunchedA.load(UserProgress.self, for: .progress)?.totalFocusMiles == 121,
                  relaunchedA.load(UserProfile.self, for: .profile)?.lastDailyGiftDay == 7_500 else {
                return "Daily Gift credit and claim marker did not relaunch atomically"
            }
            relaunchedA.activateAccount("user-b")
            guard relaunchedA.load(UserProgress.self, for: .progress)?.totalFocusMiles == 222,
                  relaunchedA.load(UserProfile.self, for: .profile)?.lastDailyGiftDay != 7_500 else {
                return "Daily Gift claim state leaked between accounts"
            }

            // Force two revisions, corrupt the primary, and verify recovery from
            // the immediately preceding valid snapshot rather than resetting.
            service.activateAccount("user-a")
            accountA.totalFocusMiles = 333
            service.save(accountA, for: .progress)
            accountA.totalFocusMiles = 334
            service.save(accountA, for: .progress)
            let accountAStorage = storageKey(for: "user-a")
            try Data("not-json".utf8).write(
                to: primaryURL(storageKey: accountAStorage, rootURL: testRoot),
                options: [.atomic]
            )
            let recovered = PersistenceService(defaults: testDefaults, rootURL: testRoot)
            recovered.activateAccount("user-a")
            guard recovered.load(UserProgress.self, for: .progress)?.totalFocusMiles == 333 else {
                return "Corrupted primary did not recover its last-known-good backup"
            }
        } catch {
            return "Persistence regression setup failed: \(error.localizedDescription)"
        }
        return nil
    }
    #endif
}
