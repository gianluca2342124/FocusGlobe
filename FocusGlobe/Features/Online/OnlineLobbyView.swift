import SwiftUI

/// The private-room lobby: real participants only (never decorative fillers),
/// clear empty invite slots, Ready state, and the owner's Start. Devices sync
/// via shared timestamps — no millisecond choreography.
struct OnlineLobbyView: View {
    let room: FocusRoom
    var onStart: (() -> Void)? = nil
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var showInvite = false
    @State private var ready = false

    private var isOwner: Bool { room.ownerPublicID == online.profile?.publicID }
    private var sky: FocusSky { FocusSky.byID(room.skyID) ?? .goldenHour }

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
                summary
                actions
            }
            .padding(AppSpacing.screen)
        }
        .task {
            await online.joinRoom(room)
            await online.loadParticipants(of: room)
        }
        .refreshableIfAvailable { await online.loadParticipants(of: room) }
        .sheet(isPresented: $showInvite) {
            InvitePeopleView(context: .room(room))
                .environmentObject(online).environmentObject(appModel)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            HStack {
                Button { appModel.tapFeedback(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                Spacer()
            }
            Text(room.title)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("\(sky.name) · hosted by \(online.activeRoomParticipants.first(where: { $0.publicID == room.ownerPublicID })?.displayName ?? "a pilot")")
                .font(AppTypography.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var slots: some View {
        let participants = online.activeRoomParticipants
        let empty = max(0, min(room.maximumParticipants, FocusRoom.participantLimit) - participants.count)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: AppSpacing.sm)],
                         spacing: AppSpacing.sm) {
            ForEach(participants) { p in
                VStack(spacing: 5) {
                    BalloonView(height: 54, showBurner: false, showGlow: false,
                                skin: BalloonSkin.skin(id: p.balloonSkinID))
                    Text(p.displayName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(p.status == .ready ? "Ready" : (p.status == .flying ? "Flying" : "Joined"))
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(p.status == .ready || p.status == .flying
                                         ? Color(hex: 0x4ADE80) : .white.opacity(0.55))
                }
                .padding(10)
                .glassBackground(cornerRadius: 16, tintOpacity: 0.24, shadowRadius: 6, shadowY: 3)
            }
            ForEach(0..<empty, id: \.self) { _ in
                Button { appModel.tapFeedback(); showInvite = true } label: {
                    VStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(height: 54)
                        Text("Invite a friend")
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4])))
                }
                .buttonStyle(SoftPressStyle())
            }
        }
    }

    private var summary: some View {
        Text("Everyone focuses side by side — coins double when your Crew flies with you for 5+ minutes.")
            .font(AppTypography.caption)
            .foregroundStyle(.white.opacity(0.75))
            .multilineTextAlignment(.center)
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.sm) {
            if isOwner {
                AppPrimaryButton(title: "Start Flight", systemImage: "arrow.up") {
                    appModel.tapFeedback()
                    Task { await online.ownerStart(room, durationSeconds: nil) }
                    online.pendingRoom = room
                    dismiss()
                    onStart?()
                }
                Button("Invite Friends") { appModel.tapFeedback(); showInvite = true }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                AppPrimaryButton(title: ready ? "Ready ✓" : "I'm Ready", systemImage: "checkmark") {
                    appModel.tapFeedback()
                    ready.toggle()
                    Task { await online.setReady(room, ready: ready) }
                }
                Button("Leave Room") {
                    appModel.tapFeedback()
                    Task { await online.leaveRoom(room) }
                    dismiss()
                }
                .font(AppTypography.callout)
                .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

private extension View {
    @ViewBuilder
    func refreshableIfAvailable(_ action: @escaping () async -> Void) -> some View {
        self.refreshable { await action() }
    }
}
