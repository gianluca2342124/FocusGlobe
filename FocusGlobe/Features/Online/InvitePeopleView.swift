import SwiftUI
import CloudKit
#if canImport(UIKit)
import UIKit
#endif

/// The invitation sheet. Room-backed contexts (private flight, existing room,
/// Sky-unlock campaign) deliver invitations EXCLUSIVELY as private CKShare
/// participants: the share's `publicPermission` is `.none`, so a forwarded
/// URL grants an uninvited account nothing. Delivery goes through the system
/// CloudKit sharing sheet (Messages / WhatsApp / AirDrop, private
/// participants), or through a deliberately picked contact resolved into an
/// explicit participant. There is no Copy Link for private rooms — a copied
/// raw URL cannot carry private participant authorization.
/// The `.app` context shares only marketing text (no CloudKit access at all).
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
    @State private var share: CKShare?
    @State private var loading = true
    @State private var showContactExplainer = false
    @State private var showContactPicker = false
    @State private var showCloudSharing = false
    @State private var contactStatus: String?
    @State private var copied = false

    private var isAppContext: Bool { if case .app = context { return true }; return false }

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                header
                if loading {
                    ProgressView().tint(AppColors.gold).padding(.vertical, AppSpacing.xl)
                } else if isAppContext {
                    appMethods
                } else if share == nil {
                    OnlineUnavailableView(availability: online.availability)
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
        .alert("Invite someone you know", isPresented: $showContactExplainer) {
            Button("Choose a Contact") { showContactPicker = true }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Choose a contact to send your private FocusGlobe invitation. Your contacts stay on your device and are never uploaded.")
        }
        .sheet(isPresented: $showContactPicker) {
            ContactPicker(onPick: { _, email, phone in
                showContactPicker = false
                Task { await inviteContact(email: email, phone: phone) }
            })
        }
        .sheet(isPresented: $showCloudSharing) {
            if let share {
                CloudSharingView(share: share)
                    .ignoresSafeArea()
            }
        }
    }

    private func prepare() async {
        switch context {
        case .app:
            loading = false
        case .preFlight(let skyID):
            if let pending = online.pendingRoom {
                invitation = RoomInvitation(id: pending.id, room: pending, url: pending.shareURL)
            } else {
                invitation = await online.createRoom(skyID: skyID, title: "FocusGlobe Flight")
            }
            if let room = invitation?.room { share = await online.share(for: room) }
            loading = false
        case .room(let room):
            invitation = RoomInvitation(id: room.id, room: room, url: room.shareURL)
            share = await online.share(for: room)
            loading = false
        case .skyUnlock(let sky):
            invitation = await online.campaignInvitation(for: sky)
            if let room = invitation?.room { share = await online.share(for: room) }
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
                 : "Private iCloud invitations — only pilots you invite can join.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Private-room delivery (explicit CKShare participants only)

    private var roomMethods: some View {
        VStack(spacing: AppSpacing.sm) {
            Button {
                appModel.tapFeedback()
                showCloudSharing = true
            } label: {
                methodRow(icon: "square.and.arrow.up", title: "Send private invitation",
                          subtitle: "Messages, WhatsApp, AirDrop — invited pilots only")
            }
            .buttonStyle(SoftPressStyle())

            Button {
                appModel.tapFeedback()
                showContactExplainer = true
            } label: {
                methodRow(icon: "person.crop.circle.badge.plus", title: "Invite from Contacts",
                          subtitle: "Pick one person — contacts never leave your device")
            }
            .buttonStyle(SoftPressStyle())

            if let contactStatus {
                Text(contactStatus)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2)
            }
        }
    }

    /// Resolve the picked contact into an explicit private participant, then
    /// hand delivery to the system sharing sheet. If the address can't be
    /// resolved to an iCloud user, fall back to the sharing sheet — never to
    /// a public link.
    private func inviteContact(email: String?, phone: String?) async {
        guard let room = invitation?.room else { return }
        if let error = await online.addRoomParticipant(room, email: email, phone: phone) {
            contactStatus = error
        } else {
            contactStatus = "Invited — now send the invitation so they can accept."
            share = await online.share(for: room)
        }
        showCloudSharing = true
    }

    // MARK: App sharing (marketing text only — no CloudKit involved)

    private var appMethods: some View {
        VStack(spacing: AppSpacing.sm) {
            ShareLink(item: CloudShareService.appLink) {
                methodRow(icon: "square.and.arrow.up", title: "Share FocusGlobe",
                          subtitle: "Messages, WhatsApp, AirDrop and more")
            }
            .simultaneousGesture(TapGesture().onEnded { appModel.tapFeedback() })

            Button {
                appModel.tapFeedback()
                UIPasteboard.general.string = CloudShareService.appLink
                withAnimation { copied = true }
            } label: {
                methodRow(icon: copied ? "checkmark" : "doc.on.doc",
                          title: copied ? "Copied" : "Copy message",
                          subtitle: "Paste it anywhere")
            }
            .buttonStyle(SoftPressStyle())
        }
    }

    private func methodRow(icon: String, title: String, subtitle: String) -> some View {
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
