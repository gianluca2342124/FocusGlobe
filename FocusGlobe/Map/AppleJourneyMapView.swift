//  AppleJourneyMapView.swift
//
//  Historical placeholder. Apple Maps / MapKit is now implemented:
//
//   • Active in-flight map → `AppleActiveJourneyMapView` (AppleActiveJourneyMapView.swift)
//   • Backdrop maps (Home / Choose Journey / Boarding / Onboarding)
//                         → `AppleBackdropMapView` (AppleJourneyBackdropMap.swift)
//
//  Both consume the same provider-independent `JourneyMapData` / backdrop inputs
//  as the Google renderers, and the active provider is chosen at runtime by
//  `FocusGlobeMapProvider` (default `.apple`). Google Maps remains as a
//  migration-phase fallback. See APPLE_MAPS_MIGRATION.md.
//
//  This file intentionally declares no type (kept only to preserve history /
//  avoid churn). It can be deleted in the future Google-removal cleanup.
