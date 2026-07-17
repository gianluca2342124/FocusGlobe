import SwiftUI

/// **Flight Participants** — the ONE roster screen for an active Private Flight.
/// The flight is already airborne, so there is NO Ready, NO Start Flight, NO
/// countdown and NO pre-flight language: it is purely a live roster you can
/// invite into or leave. The host sees Invite Friends + Done; an invited member
/// sees Leave Flight + Done. Invited pilots only — never decorative fillers.
struct OnlineLobbyView: View {
    let room: FocusRoom
    /// Retained for source compatibility; the screen is always the roster now.
    var asParticipants: Bool = true
    var onStart: (() -> Void)? = nil
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var shareURL: URL?
    @State private var inviteBusy = false

    private var isOwner: Bool { room.ownerPublicID == online.currentUserID }
    private var sky: FocusSky { FocusSky.byID(room.skyID) ?? .goldenHour }
    private var pilotCount: Int { online.activeRoomParticipants.count }

    var body: some View {
        ZStack {
            SkyFlightSceneView(sky: sky, elapsed: { 30 }, animated: false)
                .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.5), .black.opacity(0.25), .black.opacity(0.6)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                header
                slots
                Spacer()
                actions
            }
            .padding(AppSpacing.screen)
        }
        // A lightweight roster read (no realtime subscription, no lobby state) —
        // the current flight's poll keeps this list live; a room opened from
        // Friends just needs one fetch.
        .task { await online.loadParticipants(of: room) }
        .refreshableIfAvailable { await online.loadParticipants(of: room) }
        #if canImport(UIKit)
        .sheet(item: Binding(get: { shareURL.map { LobbyShareURL(url: $0) } },
                             set: { shareURL = $0?.url })) { item in
            InviteShareSheet(url: item.url)
        }
        #endif
    }

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Flight Participants")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .tracking(1).foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button { appModel.tapFeedback(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.ultraThinMaterial))
                }
            }
            Text(sky.name)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                pill(durationLabel, icon: "clock")
                pill("\(pilotCount) / \(room.maximumParticipants) pilots", icon: "person.2.fill")
            }
        }
    }

    private func pill(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.85))
        .padding(.horizontal, 11).padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
    }

    private var durationLabel: String {
        guard let end = room.endsAt else { return "Infinite" }
        let r = max(0, Int(end.timeIntervalSinceNow))
        return r >= 60 ? "\(r / 60) min left" : "Landing soon"
    }

    private var slots: some View {
        LobbySeatGrid(participants: online.activeRoomParticipants,
                      ownerID: room.ownerPublicID,
                      myID: online.currentUserID,
                      capacity: room.maximumParticipants,
                      onInviteSeat: { if isOwner { Task { await inviteFriends() } } })
            .animation(.spring(response: 0.42, dampingFraction: 0.82),
                       value: online.activeRoomParticipants)
    }

    @ViewBuilder private var actions: some View {
        if isOwner {
            VStack(spacing: AppSpacing.sm) {
                AppPrimaryButton(title: inviteBusy ? "Preparing…" : "Invite Friends",
                                 systemImage: "person.badge.plus") {
                    guard !inviteBusy else { return }
                    appModel.tapFeedback()
                    Task { await inviteFriends() }
                }
                .disabled(inviteBusy)
                Button("Done") { appModel.tapFeedback(); dismiss() }
                    .font(AppTypography.callout)
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else {
            VStack(spacing: AppSpacing.sm) {
                Button("Done") { appModel.tapFeedback(); dismiss() }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Button("Leave Flight") {
                    appModel.tapFeedback()
                    Task { await online.leaveRoom(room) }
                    dismiss()
                }
                .font(AppTypography.callout)
                .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    /// Mint ONE fresh single-use link and hand it straight to the iOS share
    /// sheet. In-flight guarded so a double tap can't create two links.
    private func inviteFriends() async {
        guard !inviteBusy else { return }
        inviteBusy = true
        if let url = await online.freshInvite(for: room) { shareURL = url }
        inviteBusy = false
    }
}

/// Identifiable wrapper so a URL can drive `.sheet(item:)` for the share sheet.
private struct LobbyShareURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private extension View {
    @ViewBuilder
    func refreshableIfAvailable(_ action: @escaping () async -> Void) -> some View {
        self.refreshable { await action() }
    }
}
