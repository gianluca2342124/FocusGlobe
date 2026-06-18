//  AppleJourneyMapView.swift
//
//  FUTURE MIGRATION TARGET — Apple Maps / MapKit.
//
//  Google Maps is the temporary MVP provider. When we migrate, this file
//  becomes the real map renderer and `JourneyMapView` switches to it. The key
//  point of the architecture: this renderer consumes the exact same
//  `JourneyMapData` as the Google renderer, so NONE of the journey, timer,
//  progress or reward logic changes during migration. See
//  MAP_PROVIDER_MIGRATION.md for the full checklist.
//
//  Sketch of the eventual implementation (intentionally left commented so the
//  project builds today without taking a MapKit dependency for the journey
//  screen):
//
//  import SwiftUI
//  import MapKit
//
//  struct AppleJourneyMapView: View {
//      let data: JourneyMapData
//
//      var body: some View {
//          Map(position: .constant(.camera(MapCamera(
//              centerCoordinate: CLLocationCoordinate2D(
//                  latitude: data.vehicle.latitude,
//                  longitude: data.vehicle.longitude),
//              distance: distance(forZoom: CameraController.zoom(forDistanceKm: data.routeDistanceKm))
//          )))) {
//              // Full route — reuse MapRouteRenderer.routePoints(...)
//              MapPolyline(coordinates: MapRouteRenderer
//                  .routePoints(from: data.origin, to: data.destination)
//                  .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
//                  .stroke(data.theme.soft.opacity(0.5), lineWidth: 4)
//
//              // Travelled route — reuse MapRouteRenderer.traveledPoints(...)
//              MapPolyline(coordinates: MapRouteRenderer
//                  .traveledPoints(from: data.origin, to: data.vehicle)
//                  .map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) })
//                  .stroke(data.theme.accent, lineWidth: 6)
//
//              Annotation("", coordinate: CLLocationCoordinate2D(
//                  latitude: data.vehicle.latitude, longitude: data.vehicle.longitude)) {
//                  BalloonMark(size: 40, glow: data.theme.soft)
//              }
//          }
//          .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
//      }
//  }
