import Foundation

/// Visual identity used to render an abstract, premium "destination memory"
/// postcard in SwiftUI (no external images, no cartoons). Each case maps to a
/// soft silhouette drawn procedurally over the destination's mood gradient.
enum Landmark: String, Codable, Hashable {
    case pagoda      // Kyoto, temples, East-Asian roofs
    case dome        // Santorini, white domes
    case tower       // Paris, Tokyo, spires
    case skyline     // big cities
    case mountain    // alps, peaks
    case coastline   // Amalfi, Big Sur, cliffs by sea
    case island      // tropical / palm
    case aurora      // northern lights, polar
    case desert      // dunes
    case forest      // green wilderness
    case canyon      // mesas, gorges
    case bridge      // harbours, crossings
    case generic     // soft hills (fallback)
}
