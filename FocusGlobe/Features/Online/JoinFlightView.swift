import SwiftUI

/// The compact invitation screen a guest sees after opening a private-flight
/// link. Backed by a READ-ONLY preview — opening the link never joined, never
/// consumed the token, never changed the count. The flight is ALREADY airborne,
/// so there is NO lobby, no Ready, no Start Flight, no duration picker and no
/// ritual. Only `Join Flight` performs the atomic accept + membership; `Not now`
/// simply dismisses with no backend mutation. Invalid/expired/full/blocked
/// invitations are filtered upstream, so this only shows for a joinable flight.
struct JoinFlightView: View {
    let preview: FocusOnlineModel.InvitePreviewState
    var onJoin: () -> Void
    var onDecline: () -> Void
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var online: FocusOnlineModel

    private var room: FocusRoom { preview.room }
    private var sky: FocusSky { FocusSky.byID(room.skyID) ?? .defaultFree }

    /// Live remaining, derived from the canonical `ends_at` — updates while the
    /// screen is visible so the guest sees the true shared time before joining.
    /// The TimelineView tick is shifted into SERVER-clock space (via the offset
    /// captured on preview) so the preview matches the deadline the guest will
    /// actually inherit, regardless of this device's wall-clock skew.
    private func remainingLabel(_ now: Date) -> String {
        guard let end = room.endsAt else { return "Infinite Flight" }
        let adjustedNow = now.addingTimeInterval(online.serverClockOffset)
        let r = max(0, Int(end.timeIntervalSince(adjustedNow)))
        return r >= 60 ? "\(r / 60) min remaining" : "Landing soon"
    }

    var body: some View {
        ZStack {
            SkyFlightSceneView(
                sky: sky,
                elapsed: { 30 },
                animated: false,
                presentationMode: .socialPreview,
                renderQuality: .still
            )
            .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.3), .black.opacity(0.65)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                Spacer()
                BalloonView(height: 100, showBurner: false, showGlow: true,
                            skin: BalloonSkin.skin(id: preview.hostSkin))
                VStack(spacing: 6) {
                    Text("Join \(preview.hostAlias)'s Flight")
                        .font(.system(size: 26, weight: .bold, design: .default))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                    Text("You'll join the flight already in progress.")
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    HStack(spacing: 8) {
                        infoPill(sky.name, icon: "sparkles")
                        infoPill(remainingLabel(ctx.date), icon: "clock")
                        infoPill("\(preview.participantCount) flying", icon: "person.2.fill")
                    }
                }
                Spacer()
                VStack(spacing: AppSpacing.sm) {
                    AppPrimaryButton(title: "Join Flight", systemImage: "arrow.up", iconTrailing: true) {
                        appModel.tapFeedback(); onJoin()
                    }
                    Button("Not now") { appModel.tapFeedback(); onDecline() }
                        .font(AppTypography.callout)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(AppSpacing.screen)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func infoPill(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 12.5, weight: .semibold, design: .default)).monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
    }
}
