import SwiftUI

/// A single "today's goal". Pure display data — progress is computed by
/// `AppModel` from the on-device session history each time it's read, so missions
/// reset naturally at midnight with no scheduler or persistence of their own.
struct DailyMission: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let accent: RouteTheme
    /// Target amount (journeys, minutes, miles…) and current amount toward it.
    let target: Double
    let current: Double

    var isComplete: Bool { current >= target }
    var fraction: Double { target <= 0 ? 1 : min(1, current / target) }

    /// Compact "2 / 30" style progress label.
    var progressText: String {
        let cur = min(current, target)
        return "\(Int(cur.rounded(.down))) / \(Int(target))"
    }
}
