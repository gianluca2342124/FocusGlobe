import SwiftUI

/// The compact invitation screen a guest sees after opening a private-flight
/// link. The flight is ALREADY airborne — so there is NO lobby, no Ready, no
/// Start Flight, no duration picker and no ritual. `Join Flight` launches the
/// guest straight into the host's active flight with the synchronized remaining
/// time; `Not now` declines and releases the membership. Friendly error states
/// (ended / expired / full / blocked / offline) are surfaced upstream before
/// this screen ever appears — it only shows for a genuinely joinable flight.
struct JoinFlightView: View {
    let room: FocusRoom
    var onJoin: () -> Void
    var onDecline: () -> Void
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel

    private var sky: FocusSky { FocusSky.byID(room.skyID) ?? .goldenHour }
    private var host: RoomParticipant? {
        online.activeRoomParticipants.first { $0.publicID == room.ownerPublicID }
    }
    private var hostAlias: String {
        if let name = host?.displayName, !name.isEmpty { return name }
        return "a pilot"
    }
    private var remainingLabel: String {
        guard let end = room.endsAt else { return "Infinite Flight" }
        let r = max(0, Int(end.timeIntervalSinceNow))
        return r >= 60 ? "\(r / 60) min remaining" : "Landing soon"
    }

    var body: some View {
        ZStack {
            SkyFlightSceneView(sky: sky, elapsed: { 30 }, animated: false).ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.55), .black.opacity(0.3), .black.opacity(0.65)],
                           startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(spacing: AppSpacing.lg) {
                Spacer()
                BalloonView(height: 100, showBurner: false, showGlow: true,
                            skin: BalloonSkin.skin(id: host?.balloonSkinID ?? "default"))
                VStack(spacing: 6) {
                    Text("Join \(hostAlias)'s Flight")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2).minimumScaleFactor(0.7)
                    Text("You'll join the flight already in progress.")
                        .font(AppTypography.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                HStack(spacing: 8) {
                    infoPill(sky.name, icon: "sparkles")
                    infoPill(remainingLabel, icon: "clock")
                    infoPill("\(online.activeRoomParticipants.count) flying", icon: "person.2.fill")
                }
                Spacer()
                VStack(spacing: AppSpacing.sm) {
                    AppPrimaryButton(title: "Join Flight", systemImage: "arrow.up") {
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
            Text(text).font(.system(size: 12.5, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
    }
}
