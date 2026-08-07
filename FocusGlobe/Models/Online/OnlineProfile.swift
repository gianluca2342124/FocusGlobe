import Foundation

/// The user's public face: anonymous by default, never containing personal
/// onboarding data, email, phone, or precise location.
struct OnlineProfile: Codable, Equatable, Sendable {
    let publicID: String
    var displayName: String
    var balloonSkinID: String
    var countryCode: String?
    var isDiscoverable: Bool
    var allowsFriendRequests: Bool
    var createdAt: Date
    var updatedAt: Date
}

/// THE rules for a public name. One definition, so the client and
/// `claim_public_alias` can never disagree about what is valid or what counts
/// as the same name.
enum PublicName {
    static let minLength = 3
    static let maxLength = 20

    /// Trim, then cap. What the pilot SEES keeps its casing.
    static func display(_ raw: String) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxLength))
    }

    /// The comparison key: trimmed and lowercased, exactly as the database's
    /// `lower(btrim(public_alias))` unique index computes it. "Alex", " alex "
    /// and "ALEX" all reduce to `alex`, which is what makes them one name.
    static func key(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func isSameName(_ a: String, _ b: String) -> Bool { key(a) == key(b) }

    /// Mirrors the server's own acceptance rules AND `updateAlias`'s existing
    /// ones, so nothing gets past the keyboard that the network would reject.
    /// Returns a user-facing message, or nil when the name is fine.
    static func validationMessage(for raw: String) -> String? {
        let name = display(raw)
        guard name.count >= minLength, name.count <= maxLength else {
            return "Name must be \(minLength)–\(maxLength) characters."
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_ "))
        guard name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "Only letters, numbers, spaces and _ are allowed."
        }
        guard name.rangeOfCharacter(from: .alphanumerics) != nil else {
            return "Add a few letters or numbers."
        }
        guard !name.lowercased().contains("http") else { return "Links aren't allowed." }
        let banned = ["fuck", "shit", "bitch", "nazi", "cunt"]
        guard !banned.contains(where: { name.lowercased().contains($0) }) else {
            return "Please pick a friendlier name."
        }
        return nil
    }

    /// The generated default, mirroring `private.random_alias` word-for-word so
    /// a locally-assigned name and a server-assigned one are the same kind of
    /// thing. Readable, neutral, nothing personal, nothing UUID-shaped.
    ///
    /// `attempt` past 3 appends two digits — the same escalation the server
    /// uses, so a collision-heavy retry loop widens the space instead of
    /// hammering 225 candidates forever.
    static func generated(attempt: Int = 0) -> String {
        let adjectives = ["Quiet", "Silver", "Calm", "Blue", "Soft", "Bright", "Still",
                          "Golden", "Gentle", "Northern", "Amber", "Silent", "Clear",
                          "Warm", "Distant"]
        let nouns = ["Comet", "Cloud", "Orbit", "Lantern", "Horizon", "Drift", "Ember",
                     "Meridian", "Compass", "Beacon", "Summit", "Current", "Aurora",
                     "Harbor", "Voyage"]
        var name = (adjectives.randomElement() ?? "Quiet") + (nouns.randomElement() ?? "Comet")
        if attempt > 3 { name += String(Int.random(in: 10...99)) }
        return String(name.prefix(maxLength))
    }
}

extension OnlineProfile {
    /// THE generated public alias.
    ///
    /// One generator, shared by the client and (in word list and shape) by
    /// `private.random_alias`. It replaced the old `SkyPilot####`, which was
    /// written out twice and offered only 9,000 possibilities — far too few to
    /// sit behind a global uniqueness constraint.
    static func generatedAlias(attempt: Int = 0) -> String {
        PublicName.generated(attempt: attempt)
    }
}
