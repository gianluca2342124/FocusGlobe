import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

/// The single upgrade surface presented everywhere (crown, Ultra lock, premium
/// skins, "go Pro"). Shows the native **RevenueCat paywall** when RevenueCatUI
/// is linked; otherwise falls back to the built-in `PaywallView` so the app
/// always has a working upgrade screen. All triggers call
/// `router.presentPaywall()`, so swapping the content here updates them all.
struct PaywallContainerView: View {
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if canImport(RevenueCatUI)
        RevenueCatUI.PaywallView(displayCloseButton: true)
            .onPurchaseCompleted { _ in
                appModel.subscriptions.refresh()
                dismiss()
            }
            .onRestoreCompleted { _ in
                appModel.subscriptions.refresh()
                dismiss()
            }
            .ignoresSafeArea()
        #else
        PaywallView()
        #endif
    }
}
