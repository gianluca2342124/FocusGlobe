import MapKit
import UIKit

/// Fades a freshly-created `MKMapView` in once its first tiles have rendered, so
/// screens never flash blank grey while MapKit streams tiles (very visible in the
/// Simulator). A safety timeout guarantees the map still becomes visible even if
/// rendering is slow or never completes (e.g. offline), so it is never left
/// invisible. One instance per map/coordinator; the reveal fires at most once.
///
/// Deliberately not `@MainActor`: it mirrors the map coordinators (plain
/// `NSObject`s driven on the main thread via `MKMapViewDelegate` callbacks and
/// `DispatchQueue.main`), and only ever touches UIKit from those main-thread
/// paths.
final class MapReveal {
    private var revealed = false

    /// Hide the map and arm the safety timeout. Call from `makeUIView`.
    func arm(_ map: MKMapView, timeout: TimeInterval = 2.5) {
        map.alpha = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self, weak map] in
            guard let self, let map else { return }
            self.reveal(map)
        }
    }

    /// Fade the map in exactly once. Safe to call repeatedly (e.g. from every
    /// `mapViewDidFinishRenderingMap` pass) — only the first call takes effect.
    func reveal(_ map: MKMapView) {
        guard !revealed else { return }
        revealed = true
        UIView.animate(withDuration: 0.55, delay: 0, options: .curveEaseOut) {
            map.alpha = 1
        }
    }
}
