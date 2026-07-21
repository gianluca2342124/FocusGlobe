import Foundation
import SwiftUI

/// The active-flight world entry point — a thin router into the single
/// authoritative renderer, `SkyFlightSceneView` (the living animated sky).
///
/// History note: this file once hosted the scrolling "world tape" (chapter
/// library, authored journeys, per-Sky palette contracts). That system produced
/// travelling scenery, geometric compositions and cloud walls, and was removed
/// in favour of the living-sky direction: an evolving gradient, a permanent
/// Ground, and local fading atmospheric moments. Exterior flight, Cabin View
/// and premium previews all render through the same view, seed and pause-aware
/// clock — switching cameras never changes the world.
struct ActiveFlightJourneyWorldView: View {
    /// Live elapsed focus seconds (pause-aware), read every frame.
    let elapsed: () -> Double
    /// Stable per-session seed: effect placement varies between flights.
    var seed: UInt64 = 1
    var animated: Bool = true
    /// The flight's Sky. Legacy resumes without a resolvable Sky fall back to
    /// the free Sky rather than to any separate renderer.
    var focusSky: FocusSky? = nil

    var body: some View {
        SkyFlightSceneView(sky: focusSky ?? .defaultFree,
                           elapsed: elapsed, animated: animated, seed: seed)
    }
}
