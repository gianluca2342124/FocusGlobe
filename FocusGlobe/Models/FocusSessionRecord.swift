import Foundation

/// The canonical FocusGlobe distance metric. The pilot's balloon drifts at a
/// calm **15 km/h**, so the distance travelled is derived purely from REAL
/// focused time — never geography, never a per-session round-up. This is the ONE
/// source used by Success, History and every Passport distance total, so a
/// session's distance can never disagree between surfaces. Distance is a stat
/// only; it is NEVER used for unlock requirements.
enum FocusMetrics {
    /// The balloon's cruising speed used for the focus-distance metric.
    static let cruiseKmPerHour: Double = 15

    /// Focus distance for a given amount of real focused time.
    static func distanceKm(focusedSeconds: Int) -> Double {
        Double(max(0, focusedSeconds)) / 3600.0 * cruiseKmPerHour
    }
}

/// A persisted record of a focus session, completed (landed) or cancelled.
struct FocusSessionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    let routeID: String
    let routeName: String
    let originName: String
    let destinationName: String
    let mood: RouteMood
    let theme: RouteTheme
    let date: Date
    let plannedMinutes: Int
    let focusedSeconds: Int
    let distanceKm: Double
    let focusMiles: Int
    let intention: String?
    /// `true` if the user reached the destination, `false` if cancelled early.
    let completed: Bool

    var focusedMinutes: Int { focusedSeconds / 60 }

    /// The canonical focus distance for this record — always recomputed from
    /// real focused time, so legacy records that stored a geographic distance
    /// display the correct value too. Prefer this over the stored `distanceKm`
    /// at every display/stat site.
    var focusDistanceKm: Double { FocusMetrics.distanceKm(focusedSeconds: focusedSeconds) }

    init(id: UUID = UUID(),
         routeID: String,
         routeName: String,
         originName: String,
         destinationName: String,
         mood: RouteMood,
         theme: RouteTheme,
         date: Date = Date(),
         plannedMinutes: Int,
         focusedSeconds: Int,
         distanceKm: Double,
         focusMiles: Int,
         intention: String?,
         completed: Bool) {
        self.id = id
        self.routeID = routeID
        self.routeName = routeName
        self.originName = originName
        self.destinationName = destinationName
        self.mood = mood
        self.theme = theme
        self.date = date
        self.plannedMinutes = plannedMinutes
        self.focusedSeconds = focusedSeconds
        self.distanceKm = distanceKm
        self.focusMiles = focusMiles
        self.intention = intention
        self.completed = completed
    }

    private enum CodingKeys: String, CodingKey {
        case id, routeID, routeName, originName, destinationName, mood, theme
        case date, plannedMinutes, focusedSeconds, distanceKm, focusMiles
        case intention, completed
    }

    /// Historical records are Passport evidence. Decode conservatively and
    /// independently so a field added by a later build cannot erase the entire
    /// journey history. Missing completion always defaults to `false`, which
    /// cannot fabricate Coins, a landing, or a streak.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        routeID = (try? c.decode(String.self, forKey: .routeID)) ?? "legacy"
        routeName = (try? c.decode(String.self, forKey: .routeName)) ?? "Focus Flight"
        originName = (try? c.decode(String.self, forKey: .originName)) ?? "Unknown"
        destinationName = (try? c.decode(String.self, forKey: .destinationName)) ?? "Unknown"
        mood = (try? c.decode(RouteMood.self, forKey: .mood)) ?? .calm
        theme = (try? c.decode(RouteTheme.self, forKey: .theme)) ?? .teal
        date = (try? c.decode(Date.self, forKey: .date)) ?? .distantPast
        plannedMinutes = max(0, (try? c.decode(Int.self, forKey: .plannedMinutes)) ?? 0)
        focusedSeconds = max(0, (try? c.decode(Int.self, forKey: .focusedSeconds)) ?? 0)
        distanceKm = max(0, (try? c.decode(Double.self, forKey: .distanceKm)) ?? 0)
        focusMiles = max(0, (try? c.decode(Int.self, forKey: .focusMiles)) ?? 0)
        intention = try? c.decode(String.self, forKey: .intention)
        completed = (try? c.decode(Bool.self, forKey: .completed)) ?? false
    }
}
