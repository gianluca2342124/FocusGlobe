import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The **Focus Coin** mark, used in every coin chip and balance. Renders the
/// bundled `Icon_FocusCoin` art when present; otherwise a crisp procedural
/// hexagon coin so the currency always has a face, with or without assets.
struct FocusCoinIcon: View {
    var size: CGFloat = 22

    private static var hasAsset: Bool {
        #if canImport(UIKit)
        return UIImage(named: "Icon_FocusCoin") != nil
        #else
        return false
        #endif
    }

    var body: some View {
        if Self.hasAsset {
            Image("Icon_FocusCoin")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "circle.hexagongrid.circle.fill")
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(AppColors.gold)
                .accessibilityHidden(true)
        }
    }
}
