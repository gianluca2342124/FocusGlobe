import Foundation

/// A collectible postcard / stamp earned by completing a route. Shown in the
/// Globe Passport.
struct Postcard: Identifiable, Codable, Hashable {
    /// Matches the route id that unlocked it.
    let id: String
    let title: String
    let place: String
    let mood: RouteMood
    let theme: RouteTheme
    let unlockedDate: Date

    init(route: Route, unlockedDate: Date = Date()) {
        self.id = route.id
        self.title = route.rewardName
        self.place = route.destinationName
        self.mood = route.mood
        self.theme = route.colorTheme
        self.unlockedDate = unlockedDate
    }
}
