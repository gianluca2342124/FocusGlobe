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
    @State private var readyBusy = false
    @State private var startBusy = false

    private var isOwner: Bool { room.ownerPublicID == online.currentUserID }
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
            // Membership already exists (create/join RPC). This heartbeats,
            // loads members and subscribes the realtime change feed.
            await online.joinRoom(room)
        }
        .onDisappear { online.exitLobby() }
        // Shared flight start: when the OWNER starts, the server flips the room
        // to active; realtime (or the pull-to-refresh reconciliation) delivers
        // it here and every member's device takes off together.
        .onChange(of: online.activeRoomStartedID) { _, startedID in
            guard startedID == room.id, !isOwner else { return }
            online.usePendingRoom(room)
            dismiss()
            onStart?()
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
        LobbySeatGrid(participants: online.activeRoomParticipants,
                      ownerID: room.ownerPublicID,
                      myID: online.currentUserID,
                      capacity: room.maximumParticipants,
                      onInviteSeat: { appModel.tapFeedback(); showInvite = true })
            .animation(.spring(response: 0.42, dampingFraction: 0.82),
                       value: online.activeRoomParticipants)
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
                AppPrimaryButton(title: startBusy ? "Starting…" : "Start Flight", systemImage: "arrow.up") {
                    guard !startBusy else { return }
                    startBusy = true
                    appModel.tapFeedback()
                    Task {
                        await online.ownerStart(room, durationSeconds: nil)
                        online.usePendingRoom(room)
                        dismiss()
                        onStart?()
                    }
                }
                .disabled(startBusy)
                Button("Invite") { appModel.tapFeedback(); showInvite = true }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            } else {
                // Clean two-state ready: "I'm Ready" → "Ready" with ONE check;
                // in-flight guarded so double taps can't spam the mutation.
                AppPrimaryButton(title: ready ? "Ready" : "I'm Ready",
                                 systemImage: ready ? "checkmark.circle.fill" : "checkmark") {
                    guard !readyBusy else { return }
                    appModel.tapFeedback()
                    let next = !ready
                    readyBusy = true
                    withAnimation(.snappy(duration: 0.2)) { ready = next }
                    Task {
                        await online.setReady(room, ready: next)
                        readyBusy = false
                    }
                }
                .disabled(readyBusy)
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
