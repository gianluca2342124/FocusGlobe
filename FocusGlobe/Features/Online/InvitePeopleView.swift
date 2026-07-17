import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The invitation sheet. Room-backed contexts (private flight, existing room,
/// Sky-unlock campaign) share a REAL one-time invite link minted by the
/// server: the token is stored only as a hash, expires automatically, is
/// capacity-limited, and blocked users can never join with it. The `.app`
/// context shares only marketing content (no room access at all) — the two
/// flows are deliberately unmistakable.
struct InvitePeopleView: View {
    enum Context {
        case preFlight(skyID: String)          // creates the pending flight room
        case room(FocusRoom)                   // invite into an existing room
        case skyUnlock(FocusSky)               // invite-unlock campaign
        case app                               // just share FocusGlobe
    }

    let context: Context
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var invitation: RoomInvitation?
    @State private var loading = true
    @State private var copied = false
    @State private var shareURL: URL?          // drives the one-URL system share sheet
    @State private var refreshingSeat = false   // in-flight guard for "Invite to a seat"

    private var isAppContext: Bool { if case .app = context { return true }; return false }

    /// A member (not the host) viewing an existing room — they see the live
    /// lobby but can't mint invitations (owner-only on the server).
    private var isMemberRoomContext: Bool {
        if case .room(let r) = context { return r.ownerPublicID != online.currentUserID }
        return false
    }

    /// Contexts that actually create a room (and so can be throttled/failed).
    private var isRoomCreatingContext: Bool {
        switch context { case .preFlight, .skyUnlock: return true; default: return false }
    }

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                header
                if loading {
                    ProgressView().tint(AppColors.gold)
                        .padding(.vertical, AppSpacing.xl)
                    Text("Creating your private room…")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.textTertiary)
                } else if isAppContext {
                    appMethods
                } else if !online.availability.isAvailable {
                    // Genuinely signed out / offline — the ONE authoritative
                    // state (a real failure flips it; nothing else does).
                    OnlineUnavailableView(availability: online.availability)
                } else if isRoomCreatingContext, let until = online.roomThrottledUntil {
                    // Server throttle — wait out the retry window with a live
                    // countdown; never reinterpreted as "no connection".
                    throttleCard(until: until)
                } else if isRoomCreatingContext, case .failed(let failure) = online.roomCreationState,
                          invitation?.url == nil {
                    failedCard(message: failure.message)
                } else if invitation?.url == nil && !isMemberRoomContext {
                    roomErrorCard
                } else {
                    roomMethods
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.screen)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.fraction(0.62), .large])
        .presentationDragIndicator(.visible)
        .task { await prepare() }
    }

    private func prepare() async {
        switch context {
        case .app:
            loading = false
        case .preFlight(let skyID):
            if online.roomThrottledUntil != nil { loading = false; return }
            if let pending = online.pendingRoom {
                // Tokens are single-use: the stored creation-time link may
                // already be consumed, so the owner mints a fresh one each
                // time the sheet opens (server rate-limits minting).
                if pending.ownerPublicID == online.currentUserID,
                   let fresh = await online.freshInvite(for: pending) {
                    invitation = RoomInvitation(id: pending.id, room: pending, url: fresh)
                } else if pending.shareURL != nil {
                    invitation = RoomInvitation(id: pending.id, room: pending, url: pending.shareURL)
                }
            } else if let room = await online.requestPrivateFlightRoom(skyID: skyID,
                                                                       title: "FocusGlobe Flight") {
                invitation = RoomInvitation(id: room.id, room: room, url: room.shareURL)
            }
            loading = false
        case .room(let room):
            // Single-use tokens: the OWNER mints a fresh link on every open
            // (the stored one may be consumed). Members can't mint (server
            // enforces not_owner) — they get the live lobby preview with a
            // host hint instead of invite actions or a misleading error.
            if room.ownerPublicID == online.currentUserID {
                if let fresh = await online.freshInvite(for: room) {
                    invitation = RoomInvitation(id: room.id, room: room, url: fresh)
                } else if room.shareURL != nil {
                    invitation = RoomInvitation(id: room.id, room: room, url: room.shareURL)
                }
            } else {
                invitation = RoomInvitation(id: room.id, room: room, url: nil)
            }
            loading = false
        case .skyUnlock(let sky):
            if online.roomThrottledUntil != nil { loading = false; return }
            invitation = await online.campaignInvitation(for: sky)
            loading = false
        }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Capsule().fill(.white.opacity(0.2)).frame(width: 40, height: 4).padding(.top, 10)
            Text("Invite Friends")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text(isAppContext
                 ? "Share FocusGlobe with someone who needs calmer focus."
                 : "Private invitation link — only pilots with this link can join, and it expires on its own.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // A transient room-creation failure while the account IS available — offer
    // a retry, never a misleading "You're offline".
    private var roomErrorCard: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
                .padding(.bottom, 2)
            Text("Couldn't create your private room")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Please try again in a moment.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                appModel.tapFeedback()
                loading = true
                Task { await prepare() }
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.gold)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
    }

    // Server throttle — live countdown; never auto-retries.
    private func throttleCard(until: Date) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
                .padding(.bottom, 2)
            Text("The sky is busy")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text("Please wait before creating another private flight.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            TimelineView(.periodic(from: .now, by: 1)) { ctx in
                Text("Try again in \(FlightModeSelectorView.countdown(to: until, now: ctx.date))")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.gold)
                    .monospacedDigit()
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
    }

    // A terminal (non-throttle) creation failure — friendly copy + retry.
    private func failedCard(message: String) -> some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "exclamationmark.icloud")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(AppColors.textTertiary)
                .padding(.bottom, 2)
            Text("Private room unavailable")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button("Try again") {
                appModel.tapFeedback()
                loading = true
                Task { await prepare() }
            }
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.gold)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.lg)
    }

    // MARK: Private-room delivery (a lobby, with invitation as the secondary act)

    private var roomMethods: some View {
        VStack(spacing: AppSpacing.md) {
            // The lobby IS the hero: a live seat preview sits above the actions.
            if let room = invitation?.room {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: 0x4ADE80)).frame(width: 6, height: 6)
                        Text("\(FocusSky.byID(room.skyID)?.name ?? "Your Sky") · \(online.activeRoomParticipants.count)/\(room.maximumParticipants)")
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    LobbySeatGrid(participants: online.activeRoomParticipants,
                                  ownerID: room.ownerPublicID,
                                  myID: online.currentUserID,
                                  capacity: room.maximumParticipants,
                                  onInviteSeat: { Task { await inviteToSeat() } },
                                  compact: true)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8),
                                   value: online.activeRoomParticipants)
                }
            }

            if let url = invitation?.url {
                Button {
                    Task { await inviteToSeat() }
                } label: {
                    methodRow(icon: "person.crop.circle.badge.plus",
                              title: refreshingSeat ? "Preparing seat…" : "Invite to a seat",
                              subtitle: "A fresh single-use link for one friend")
                }
                .buttonStyle(SoftPressStyle())
                .disabled(refreshingSeat)

                Button {
                    appModel.tapFeedback()
                    shareURL = url
                } label: {
                    methodRow(icon: "square.and.arrow.up", title: "Share invitation",
                              subtitle: "Messages, WhatsApp, AirDrop and more")
                }
                .buttonStyle(SoftPressStyle())

                Button {
                    appModel.tapFeedback()
                    #if canImport(UIKit)
                    UIPasteboard.general.string = url.absoluteString
                    #endif
                    withAnimation { copied = true }
                } label: {
                    methodRow(icon: copied ? "checkmark" : "doc.on.doc",
                              title: copied ? "Copied" : "Copy invitation link",
                              subtitle: "Single-use · expires automatically")
                }
                .buttonStyle(SoftPressStyle())

                Text("Each link admits one new pilot, then expires — share a fresh one per friend.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            } else if isMemberRoomContext {
                Text("Only the host can invite new pilots.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
        #if canImport(UIKit)
        .sheet(item: Binding(get: { shareURL.map { ShareURL(url: $0) } },
                             set: { shareURL = $0?.url })) { item in
            InviteShareSheet(url: item.url)
        }
        #endif
        .task(id: invitation?.room.id) {
            if let room = invitation?.room { await online.loadParticipants(of: room) }
        }
    }

    /// Mint a fresh single-use invite for one seat, then open the share sheet.
    /// In-flight guarded so double taps never create two links.
    private func inviteToSeat() async {
        guard !refreshingSeat, let room = invitation?.room,
              room.ownerPublicID == online.currentUserID else { return }
        refreshingSeat = true
        appModel.tapFeedback()
        if let fresh = await online.freshInvite(for: room) {
            invitation = RoomInvitation(id: room.id, room: room, url: fresh)
            shareURL = fresh
        }
        refreshingSeat = false
    }

    // MARK: App sharing (marketing ONLY — no room, no invitation)

    /// Recommends the app: shares the App Store URL with a rich link preview
    /// (title + hero image + promo message). Never pretends to invite anyone
    /// into a room.
    private var appMethods: some View {
        VStack(spacing: AppSpacing.sm) {
            if let url = MarketingConfig.appStoreURL {
                ShareLink(item: url,
                          subject: Text(verbatim: MarketingConfig.appName),
                          message: Text(verbatim: ShareCopyService.appLink),
                          preview: SharePreview(Text(verbatim: "\(MarketingConfig.appName) — focus in the sky"),
                                                image: Image(MarketingConfig.previewImageName))) {
                    methodRow(icon: "square.and.arrow.up", title: "Share FocusGlobe",
                              subtitle: "Send an App Store link with a preview")
                }
                .simultaneousGesture(TapGesture().onEnded { appModel.tapFeedback() })
            } else {
                ShareLink(item: ShareCopyService.appLink) {
                    methodRow(icon: "square.and.arrow.up", title: "Share FocusGlobe",
                              subtitle: "Messages, WhatsApp, AirDrop and more")
                }
                .simultaneousGesture(TapGesture().onEnded { appModel.tapFeedback() })
            }

            Button {
                appModel.tapFeedback()
                #if canImport(UIKit)
                UIPasteboard.general.string = ShareCopyService.appLink
                #endif
                withAnimation { copied = true }
            } label: {
                methodRow(icon: copied ? "checkmark" : "doc.on.doc",
                          title: copied ? "Copied" : "Copy link",
                          subtitle: "Paste the App Store link anywhere")
            }
            .buttonStyle(SoftPressStyle())
        }
    }

    private func methodRow(icon: String, title: String, subtitle: String) -> some View {
        InviteMethodRow(icon: icon, title: title, subtitle: subtitle)
    }
}

/// Identifiable wrapper so a URL can drive `.sheet(item:)` for the share sheet.
private struct ShareURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// A reusable invite/method row (image chip + title + subtitle + chevron).
struct InviteMethodRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppColors.gold)
                .frame(width: 38, height: 38)
                .background(Circle().fill(AppColors.gold.opacity(0.14)))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                Text(subtitle)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.textTertiary)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .glassBackground(cornerRadius: 16, tintOpacity: 0.2, shadowRadius: 6, shadowY: 3)
    }
}

/// The two-way invite chooser: a REAL private flight (creates a room + invite
/// link) vs. simply recommending the app (marketing link, no room). Keeps the
/// two intents unambiguous so a marketing share is never mistaken for a Crew
/// invite.
struct InviteChoiceView: View {
    var onCreateRoom: () -> Void
    var onShareApp: () -> Void
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                VStack(spacing: 6) {
                    Capsule().fill(.white.opacity(0.2)).frame(width: 40, height: 4).padding(.top, 10)
                    Text("Invite someone")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                }
                Button {
                    appModel.tapFeedback()
                    onCreateRoom()
                } label: {
                    InviteMethodRow(icon: "airplane.departure", title: "Create Private Flight",
                                    subtitle: "Invite someone to focus together now.")
                }
                .buttonStyle(SoftPressStyle())

                Button {
                    appModel.tapFeedback()
                    onShareApp()
                } label: {
                    InviteMethodRow(icon: "square.and.arrow.up", title: "Share FocusGlobe",
                                    subtitle: "Recommend the app to someone.")
                }
                .buttonStyle(SoftPressStyle())

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.screen)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.fraction(0.4)])
        .presentationDragIndicator(.visible)
    }
}
