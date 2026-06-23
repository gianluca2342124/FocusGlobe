import SwiftUI
#if canImport(GoogleMaps)
import GoogleMaps
#endif

@main
struct FocusGlobeApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var router = AppRouter()

    init() {
        // Google Maps is the temporary MVP provider. Keep all business logic
        // provider-independent so we can migrate to Apple Maps / MapKit later.
        #if canImport(GoogleMaps)
        if MapConfiguration.hasValidGoogleKey {
            GMSServices.provideAPIKey(MapConfiguration.googleMapsAPIKey)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appModel)
                .environmentObject(router)
                .tint(AppColors.brand)
                .preferredColorScheme(appModel.settings.appearance.colorScheme)
                .onAppear { appModel.analytics.log(.appOpened) }
                .onOpenURL { router.handleDeepLink($0) }   // widget deep links
        }
    }
}
