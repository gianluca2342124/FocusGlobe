import Foundation

/// A collectible postcard / stamp earned by completing a route. Shown in the
/// Globe Passport.
struct Postcard: Identifiable, Codable, Hashable {
    /// Matches the destination/route id that unlocked it.
    let id: String
    let title: String
    let place: String
    let mood: RouteMood
    let theme: RouteTheme
    /// Visual identity for the procedural postcard (optional for old data).
    let landmark: Landmark?
    let unlockedDate: Date

    init(route: Route, unlockedDate: Date = Date()) {
        self.id = route.id
        self.title = route.rewardName
        self.place = route.destinationName
        self.mood = route.mood
        self.theme = route.colorTheme
        self.landmark = route.landmark
        self.unlockedDate = unlockedDate
    }
}
