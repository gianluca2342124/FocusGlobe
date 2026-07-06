import SwiftUI

/// The signature expedition call-to-action: a **paper luggage-tag** button —
/// warm cream stock, a hand-inked border, a serif label, and a small wax-seal
/// dot. It reads as a physical object stamped onto the screen, which is exactly
/// what sets the app apart from the generic filled pills of similar apps.
///
/// The colours are intentionally *fixed* (not mode-adaptive): a paper tag is
/// paper in daylight and paper by lantern-light, so it stays a bright, legible
/// label over both the dark expedition map and cream journal screens.
struct ExpeditionButton: View {
    let title: String
    var systemImage: String? = nil
    var isEnabled: Bool = true
    var isLoading: Bool = false
    /// The small wax-seal dot on the trailing edge (hide for quieter buttons).
    var showSeal: Bool = true
    let action: () -> Void

    // Fixed "paper + ink + wax" palette (matches the redesign spec tokens).
    private let paper = Color(hex: 0xF5EFE2)
    private let ink   = Color(hex: 0x2B2620)
    private let wax   = Color(hex: 0x9B3324)

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                if isLoading {
                    ProgressView().tint(ink)
                } else {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: Layout.pad(16, 19), weight: .semibold))
                    }
                    Text(title)
                        .font(.system(size: Layout.pad(18, 21), weight: .semibold, design: .serif))
                    if showSeal {
                        Circle().fill(wax)
                            .frame(width: 9, height: 9)
                            .overlay(Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                            .padding(.leading, 1)
                    }
                }
            }
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .frame(height: Layout.pad(56, 64))
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(ink.opacity(0.5), lineWidth: 1.2))
            }
            .shadow(color: .black.opacity(0.22), radius: 14, y: 8)
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(SoftPressStyle())
        .disabled(!isEnabled || isLoading)
    }
}
