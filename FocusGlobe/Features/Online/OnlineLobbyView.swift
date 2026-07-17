import SwiftUI

/// THE lobby — the single participants screen in the whole app. Two faces of the
/// same room:
///  • Guest / pre-flight (`asParticipants == false`): Sky · Duration · pilots,
///    Ready, Leave, and an elegant 3·2·1 take-off countdown when the flight
///    begins.
///  • Host in-flight roster (`asParticipants == true`): the same live seat grid
///    plus Invite Friends and Done — no Ready/Start, because the host is already
///    flying and the flight simply became private.
/// Invited pilots only — never decorative fillers. Devices sync via shared
/// timestamps; one fresh single-use link per friend, handed to the iOS share
/// sheet.
struct OnlineLobbyView: View {
    let room: FocusRoom
    /// True when opened as the in-flight host's live roster (Participants).
    var asParticipants: Bool = false
    var onStart: (() -> Void)? = nil
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ready = false
    @State private var readyBusy = false
    @State private var startBusy = false
    @State private var shareURL: URL?
    @State private var inviteBusy = false
    @State private var countdown: Int?

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

            if let n = countdown { countdownOverlay(n) }
        }
        .task {
            // The host roster reads the live poll's participants (no second
            // subscription); a guest/pre-flight lobby joins for realtime + toast.
            if !asParticipants {
                await online.joinRoom(room)
                // Joining a flight that's ALREADY airborne (the host promoted a
                // running Global Flight) takes off right away — brief lobby, then
                // the 3·2·1 into the shared sky.
                if !isOwner, room.status == .active, countdown == nil {
                    runCountdownThenStart()
                }
            }
        }
        .onDisappear { if !asParticipants { online.exitLobby() } }
        // Shared take-off: when the OWNER starts, the server flips the room
        // active; realtime delivers it and every guest takes off together with an
        // elegant countdown — synchronized to the SAME shared end.
        .onChange(of: online.activeRoomStartedID) { _, startedID in
            guard startedID == room.id, !isOwner, !asParticipants, countdown == nil else { return }
            runCountdownThenStart()
        }
        .refreshableIfAvailable { await online.loadParticipants(of: room) }
        #if canImport(UIKit)
        .sheet(item: Binding(get: { shareURL.map { LobbyShareURL(url: $0) } },
                             set: { shareURL = $0?.url })) { item in
            InviteShareSheet(url: item.url)
        }
        #endif
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Button { appModel.tapFeedback(); dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(.ultraThinMaterial))
                }
                Spacer()
            }
            Text(sky.name)
                .font(.system(size: 27, weight: .bold, design: .rounded))
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
        guard let end = room.endsAt else { return "Open flight" }
        let r = max(0, Int(end.timeIntervalSinceNow))
        return r >= 60 ? "\(r / 60) min" : "Landing soon"
    }

    private var slots: some View {
        LobbySeatGrid(participants: online.activeRoomParticipants,
                      ownerID: room.ownerPublicID,
                      myID: online.currentUserID,
                      capacity: room.maximumParticipants,
                      onInviteSeat: { Task { await inviteFriends() } })
            .animation(.spring(response: 0.42, dampingFraction: 0.82),
                       value: online.activeRoomParticipants)
    }

    // MARK: Actions

    @ViewBuilder private var actions: some View {
        if asParticipants {
            // In-flight host roster: invite + done, never restart the flight.
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
        } else if isOwner {
            VStack(spacing: AppSpacing.sm) {
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
                Button(inviteBusy ? "Preparing…" : "Invite Friends") {
                    guard !inviteBusy else { return }
                    appModel.tapFeedback(); Task { await inviteFriends() }
                }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
            }
        } else {
            VStack(spacing: AppSpacing.sm) {
                // Clean two-state ready: "I'm Ready" → "Ready" with ONE check.
                AppPrimaryButton(title: ready ? "Ready" : "I'm Ready",
                                 systemImage: ready ? "checkmark.circle.fill" : "checkmark") {
                    guard !readyBusy else { return }
                    appModel.tapFeedback()
                    let next = !ready
                    readyBusy = true
                    withAnimation(.snappy(duration: 0.2)) { ready = next }
                    Task { await online.setReady(room, ready: next); readyBusy = false }
                }
                .disabled(readyBusy)
                Button("Leave") {
                    appModel.tapFeedback()
                    Task { await online.leaveRoom(room) }
                    dismiss()
                }
                .font(AppTypography.callout)
                .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    // MARK: Invite + countdown

    /// Mint ONE fresh single-use link and hand it straight to the iOS share
    /// sheet. In-flight guarded so a double tap can't create two links.
    private func inviteFriends() async {
        guard !inviteBusy else { return }
        inviteBusy = true
        if let url = await online.freshInvite(for: room) { shareURL = url }
        inviteBusy = false
    }

    private func runCountdownThenStart() {
        online.usePendingRoom(room)
        Task {
            for n in [3, 2, 1] {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { countdown = n }
                appModel.haptics.tap()
                try? await Task.sleep(nanoseconds: 700_000_000)
            }
            withAnimation(.easeOut(duration: 0.25)) { countdown = nil }
            dismiss()
            onStart?()
        }
    }

    private func countdownOverlay(_ n: Int) -> some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 10) {
                Text("\(n)")
                    .font(.system(size: 88, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .id(n)
                    .transition(reduceMotion ? .opacity
                                : .scale(scale: 0.4).combined(with: .opacity))
                Text("Take off")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
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
