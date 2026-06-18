import Foundation

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
}
