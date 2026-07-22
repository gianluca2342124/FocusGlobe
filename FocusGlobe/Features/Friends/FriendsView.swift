import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// **Friends** — the Crew hub, backed by FocusGlobe Online (Supabase).
/// Honest by design: every pilot shown here is a real accepted connection,
/// every "Focusing now" badge comes from a real recent presence heartbeat,
/// and rooms are real private invitations. Nothing is fabricated; when the
/// crew is empty the warm empty state invites, it never pretends.
struct FriendsView: View {
    @EnvironmentObject private var appModel: AppModel
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var online: FocusOnlineModel

    @State private var lobbyRoom: FocusRoom?
    @State private var pendingGuestLaunch: FocusRoom?  // launched on preview dismiss
    @State private var inviteFlow: InviteFlow?
    @State private var removalTarget: FocusFriend?
    @State private var showSignIn = false

    /// Item-driven sheet for recommending the app (the only invite entry point
    /// on Friends — private flights are born in-flight).
    private struct InviteFlow: Identifiable {
        let id = UUID()
    }

    /// Rooms worth listing (lobby or in flight — not ended/closed),
    /// deduplicated by room id so a room never shows twice.
    private var openRooms: [FocusRoom] {
        var seen = Set<String>()
        return (online.ownedRooms + online.joinedRooms)
            .filter { $0.status == .lobby || $0.status == .active }
            .filter { seen.insert($0.id).inserted }
    }

    private var hasAnySocialContent: Bool {
        !online.crew.isEmpty || !openRooms.isEmpty
            || !online.incomingRequests.isEmpty || !online.outgoingRequests.isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    ScreenHeader(title: "Friends", showsBack: false)
                    if !online.availability.isAvailable {
                        // One compact banner near the top — the unavailable
                        // state never dominates the whole page. Signed-out
                        // offers Sign in with Apple right here.
                        OnlineUnavailableView(availability: online.availability, compact: true,
                                              onSignIn: { showSignIn = true })
                    }
                    if let message = online.inviteJoinMessage {
                        // Outcome of an invitation link that couldn't be joined
                        // (expired / full / invalid) — friendly, dismissible.
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "envelope.badge")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColors.gold)
                            Text(message)
                                .font(AppTypography.caption)
                                .foregroundStyle(AppColors.textSecondary)
                            Spacer(minLength: 0)
                            Button {
                                online.clearInviteJoinMessage()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppColors.textTertiary)
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 10)
                        .glassBackground(cornerRadius: 14, tintOpacity: 0.16, shadowRadius: 4, shadowY: 2)
                    }
                    if !hasAnySocialContent { emptyState }
                    // Active Flights · Friend Requests · Friends — nothing else.
                    if !openRooms.isEmpty { roomsSection }
                    if !online.incomingRequests.isEmpty || !online.outgoingRequests.isEmpty {
                        requestsSection
                    }
                    if !online.crew.isEmpty { crewSection }
                    inviteHero
                    if !hasAnySocialContent { howItWorks }
                }
                .padding(AppSpacing.screen)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xxl)
                .contentMaxWidth()
            }
            .refreshable { await refresh() }
        }
        .focusScreenChrome()
        .task { await refresh() }
        .onChange(of: online.availability) { _, now in
            guard now.isAvailable else { return }
            Task { await refresh() }
        }
        .sheet(isPresented: $showSignIn) {
            OnlineSignInView { Task { await refresh() } }
                .environmentObject(online)
                .environmentObject(appModel)
        }
        // Opening an invitation link only PREVIEWS the flight (no join). Join
        // Flight accepts + launches directly; Not now just dismisses.
        .sheet(item: Binding(get: { online.invitePreview },
                             set: { if $0 == nil { online.dismissInvitePreview() } }),
               onDismiss: launchPendingGuest) { preview in
            JoinFlightView(preview: preview,
                           onJoin: {
                               Task {
                                   if let room = await online.acceptInvitePreview() {
                                       pendingGuestLaunch = room   // launched on dismiss
                                   }
                               }
                           },
                           onDecline: { online.dismissInvitePreview() })
                .environmentObject(appModel)
                .environmentObject(online)
        }
        // "Open" an active flight from the list → the Flight Participants roster.
        .fullScreenCover(item: $lobbyRoom) { room in
            OnlineLobbyView(room: room)
                .environmentObject(appModel)
                .environmentObject(online)
        }
        .sheet(item: $inviteFlow) { _ in
            // From Friends you recommend the app; a Private Flight is created
            // in-flight (Invite Friends), never pre-emptively from here.
            InvitePeopleView(context: .app)
                .environmentObject(appModel)
                .environmentObject(online)
        }
        .confirmationDialog("Remove from Crew?", isPresented: Binding(
            get: { removalTarget != nil }, set: { if !$0 { removalTarget = nil } }
        ), titleVisibility: .visible) {
            Button("Remove", role: .destructive) {
                if let friend = removalTarget {
                    Task { await online.removeFriend(friend) }
                }
                removalTarget = nil
            }
            Button("Cancel", role: .cancel) { removalTarget = nil }
        } message: {
            Text("You can always reconnect later with a new request.")
        }
    }

    private func refresh() async {
        guard online.availability.isAvailable else { return }
        await online.refreshSocial()
        await online.refreshRooms()
    }

    /// Guest → launch the invited ACTIVE flight directly (no ritual, no Ready,
    /// no Start): the host's Sky, the SYNCHRONIZED remaining time, private mode.
    /// Runs after the invitation sheet has fully dismissed so the flight cover
    /// can't contend with it (mirrors Home's take-off hand-off).
    private func launchPendingGuest() {
        guard let room = pendingGuestLaunch else { return }
        pendingGuestLaunch = nil
        let sky = FocusSky.byID(room.skyID) ?? appModel.selectedSky
        // Minutes drive only the symbolic distance/route visuals — computed from
        // the server-ADJUSTED remaining so the picture matches, but the real
        // countdown below uses the RAW server deadline via the shared clock.
        let (minutes, infinite) = FocusOnlineModel.inheritedMinutes(until: online.adjustedDeadline(room.endsAt))
        online.enterInvitedFlight(room)
        let origin = appModel.originForJourney
        let route = FlightRouteFactory.route(minutes: minutes, infinite: infinite,
                                             origin: origin, focusSky: sky)
        // The guest's timer counts down to the host's RAW server deadline through
        // the shared clock — exact, skew-immune, no rounding. The curtain keeps
        // Friends from flashing while the journey cover rises; the container
        // then shows the private joining moment over the already-active flight.
        router.raiseTakeoffCurtain(skyID: sky.id)
        router.startJourney(origin: origin, route: route, intention: nil,
                            sharedEndsAt: room.endsAt)
    }

    // MARK: - Pending requests

    private var requestsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Friend Requests", icon: "envelope.fill")
            VStack(spacing: AppSpacing.xs) {
                ForEach(online.incomingRequests) { request in
                    incomingRow(request)
                }
                ForEach(online.outgoingRequests) { request in
                    outgoingRow(request)
                }
            }
        }
    }

    private func incomingRow(_ request: FriendRequest) -> some View {
        HStack(spacing: AppSpacing.sm) {
            BalloonView(height: 40, showBurner: false, showGlow: false,
                        skin: BalloonSkin.skin(id: request.senderBalloonSkinID))
            VStack(alignment: .leading, spacing: 1) {
                Text(request.senderDisplayName)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .foregroundStyle(AppColors.textPrimary)
                Text("wants to join your Crew")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
            Button {
                appModel.tapFeedback()
                Task { await online.respond(to: request, accept: false) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(SoftPressStyle())
            Button {
                appModel.tapFeedback()
                Task { await online.respond(to: request, accept: true) }
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundStyle(Color(hex: 0x14120E))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(AppColors.gold))
            }
            .buttonStyle(SoftPressStyle())
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .glassBackground(cornerRadius: 16, tintOpacity: 0.2, shadowRadius: 5, shadowY: 3)
    }

    private func outgoingRow(_ request: FriendRequest) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "paperplane.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColors.textTertiary)
                .frame(width: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("Request sent")
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .foregroundStyle(AppColors.textPrimary)
                Text("Waiting for the pilot to accept")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
            Button("Cancel") {
                appModel.tapFeedback()
                Task { await online.cancelRequest(request) }
            }
            .font(.system(size: 13, weight: .bold, design: .default))
            .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .glassBackground(cornerRadius: 16, tintOpacity: 0.14, shadowRadius: 5, shadowY: 3)
    }

    // MARK: - Crew

    private var crewSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Friends", icon: "person.2.fill")
            VStack(spacing: AppSpacing.xs) {
                ForEach(online.crew) { friend in
                    crewRow(friend)
                }
            }
        }
    }

    private func crewRow(_ friend: FocusFriend) -> some View {
        HStack(spacing: AppSpacing.sm) {
            BalloonView(height: 44, showBurner: false, showGlow: friend.activePilot != nil,
                        skin: BalloonSkin.skin(id: friend.activePilot?.balloonSkinID ?? friend.balloonSkinID))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(friend.displayName)
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .foregroundStyle(AppColors.textPrimary)
                    if let cc = friend.countryCode { Text(flagEmoji(cc)).font(.system(size: 13)) }
                }
                if let pilot = friend.activePilot {
                    HStack(spacing: 5) {
                        Circle().fill(Color(hex: 0x7FD98A)).frame(width: 6, height: 6)
                        Text("Focusing now · \(pilot.remainingLabel)")
                            .font(AppTypography.caption)
                            .foregroundStyle(Color(hex: 0x9CCFA3))
                    }
                } else {
                    Text("Crew member")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                }
            }
            Spacer()
            Menu {
                Button(role: .destructive) {
                    removalTarget = friend
                } label: {
                    Label("Remove from Crew", systemImage: "person.badge.minus")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.textTertiary)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .glassBackground(cornerRadius: 16, tintOpacity: 0.2, shadowRadius: 5, shadowY: 3)
    }

    // MARK: - Rooms / invitations

    private var roomsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionTitle("Active Flights", icon: "airplane")
            VStack(spacing: AppSpacing.xs) {
                ForEach(openRooms) { room in
                    RoomDetailsView(room: room) { lobbyRoom = $0 }
                }
            }
        }
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(AppColors.gold)
            Text(title)
                .font(.system(size: 19, weight: .bold, design: .default))
                .foregroundStyle(AppColors.textPrimary)
        }
    }

    // MARK: - Empty state

    // A warm, prominent empty state until real crew exists.
    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            crewHero
            Text("No crew yet")
                .font(.system(size: 25, weight: .bold, design: .default))
                .foregroundStyle(AppColors.textPrimary)
            Text("Invite a friend and your next flight can feel less lonely.")
                .font(AppTypography.callout)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
    }

    /// The large `nocrew` hero if present, else the procedural lonely balloon over
    /// a soft diffused glow (never a hard circle).
    @ViewBuilder private var crewHero: some View {
        #if canImport(UIKit)
        if let ui = UIImage(named: "nocrew") {
            Image(uiImage: ui).resizable().scaledToFit()
                .frame(maxHeight: Layout.pad(190, 250))
        } else {
            crewFallback
        }
        #else
        crewFallback
        #endif
    }

    private var crewFallback: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [AppColors.gold.opacity(0.24), .clear],
                                     center: .center, startRadius: 2, endRadius: 100))
                .frame(width: 170, height: 170).blur(radius: 10)
            LonelyBalloonFace().frame(width: 96, height: 116)
        }
    }

    // MARK: - Invite

    private var inviteHero: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: 7) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColors.gold)
                Text("Fly with a friend to earn 2× Focus Coins.")
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textPrimary)
            }
            Button {
                appModel.tapFeedback()
                inviteFlow = InviteFlow()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                    Text("Invite a friend")
                        .font(AppTypography.headline)
                }
                .foregroundStyle(AppColors.ctaText)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(RoundedRectangle(cornerRadius: AppSpacing.pillRadius, style: .continuous)
                    .fill(AppColors.ctaFill))
            }
            .buttonStyle(SoftPressStyle())
            Text("Send a friend FocusGlobe — then tap Invite Friends mid-flight to fly together.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textTertiary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(AppSpacing.lg)
        .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.24,
                         shadowRadius: 14, shadowY: 8)
    }

    // A single connected "journey" — numbered gold nodes linked by a flight line,
    // not three separate settings-style rows.
    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("How it works")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(AppColors.textPrimary)
            VStack(spacing: 0) {
                stepNode(1, icon: "square.and.arrow.up", title: "Share your invite",
                         subtitle: "Send a private flight link to a friend.", connector: true)
                stepNode(2, icon: "person.badge.plus", title: "Friend joins",
                         subtitle: "They accept and appear in your lobby.", connector: true)
                stepNode(3, icon: "sparkles", title: "Fly together — earn 2×",
                         subtitle: "Shared flights of 5+ minutes earn double Focus Coins.", connector: false)
            }
            .padding(AppSpacing.md)
            .glassBackground(cornerRadius: AppSpacing.cardRadius, tintOpacity: 0.2, shadowRadius: 10, shadowY: 5)
        }
    }

    private func stepNode(_ n: Int, icon: String, title: String, subtitle: String, connector: Bool) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(AppColors.gold).frame(width: 40, height: 40)
                    Text("\(n)")
                        .font(.system(size: 18, weight: .heavy, design: .default))
                        .foregroundStyle(Color(hex: 0x2B2510))
                }
                if connector {
                    Rectangle().fill(AppColors.gold.opacity(0.4)).frame(width: 2, height: 32)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.gold)
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .default))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.top, 3)
            Spacer(minLength: 0)
        }
        .padding(.bottom, connector ? 0 : 3)
    }
}

/// A tiny procedural balloon with a wistful face for the Friends empty state.
private struct LonelyBalloonFace: View {
    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                BalloonEnvelope()
                    .fill(LinearGradient(colors: [AppColors.balloonWhite, Color(hex: 0xE7DCC6)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: w, height: h * 0.82)
                    .position(x: w / 2, y: h * 0.41)
                // Two soft eyes + a small downturned mouth.
                Circle().fill(Color(hex: 0x4A4038)).frame(width: w * 0.07, height: w * 0.07)
                    .position(x: w * 0.38, y: h * 0.36)
                Circle().fill(Color(hex: 0x4A4038)).frame(width: w * 0.07, height: w * 0.07)
                    .position(x: w * 0.62, y: h * 0.36)
                MouthShape()
                    .stroke(Color(hex: 0x4A4038), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: w * 0.26, height: h * 0.08)
                    .position(x: w / 2, y: h * 0.5)
            }
        }
    }
}

private struct MouthShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                       control: CGPoint(x: rect.midX, y: rect.minY))
        return p
    }
}
