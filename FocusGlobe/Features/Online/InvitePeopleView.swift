import SwiftUI

/// The invitation sheet: creates (or reuses) the CKShare-backed room for the
/// context and offers every safe delivery route — share link, Messages/system
/// share sheet (covers WhatsApp/AirDrop), copy link, and a deliberate
/// pick-one-person contact flow. Contacts are requested ONLY here, behind an
/// explanation, via the out-of-process picker; nothing is stored or uploaded.
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
    @State private var showContactExplainer = false
    @State private var showContactPicker = false
    @State private var copied = false

    private var message: String {
        switch context {
        case .app:
            return CloudShareService.appLink
        case .skyUnlock(let sky):
            return "Help me unlock \(sky.name) in FocusGlobe — accept my invite and we both fly. \(invitation?.url?.absoluteString ?? "")"
        default:
            return CloudShareService.roomInvitation(url: invitation?.url)
        }
    }

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                header
                if loading {
                    ProgressView().tint(AppColors.gold).padding(.vertical, AppSpacing.xl)
                } else if case .app = context {
                    methods
                } else if invitation?.url == nil {
                    OnlineUnavailableView(availability: online.availability)
                } else {
                    methods
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
            ContactPicker(onPick: { _ in showSystemShare() })
        }
    }

    private func prepare() async {
        switch context {
        case .app:
            loading = false
        case .preFlight(let skyID):
            if let pending = online.pendingRoom {
                let url = await online.shareURL(for: pending)
                invitation = RoomInvitation(id: pending.id, room: pending, url: url)
            } else {
                invitation = await online.createRoom(skyID: skyID, title: "FocusGlobe Flight")
            }
            loading = false
        case .room(let room):
            let url = await online.shareURL(for: room)
            invitation = RoomInvitation(id: room.id, room: room, url: url)
            loading = false
        case .skyUnlock(let sky):
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
            Text("They join through one private link — no account needed beyond iCloud.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var methods: some View {
        VStack(spacing: AppSpacing.sm) {
            ShareLink(item: message) {
                methodRow(icon: "square.and.arrow.up", title: "Share invite link",
                          subtitle: "Messages, WhatsApp, AirDrop and more")
            }
            .simultaneousGesture(TapGesture().onEnded { appModel.tapFeedback() })

            Button {
                appModel.tapFeedback()
                showContactExplainer = true
            } label: {
                methodRow(icon: "person.crop.circle.badge.plus", title: "Invite from Contacts",
                          subtitle: "Pick one person — contacts never leave your device")
            }
            .buttonStyle(SoftPressStyle())

            Button {
                appModel.tapFeedback()
                UIPasteboard.general.string = message
                withAnimation { copied = true }
            } label: {
                methodRow(icon: copied ? "checkmark" : "doc.on.doc",
                          title: copied ? "Copied" : "Copy Link",
                          subtitle: "Paste it anywhere")
            }
            .buttonStyle(SoftPressStyle())
        }
    }

    /// After a contact is deliberately picked, hand off to the system share
    /// sheet with the invitation prefilled (nothing about the contact is kept).
    private func showSystemShare() {
        showContactPicker = false
        let activity = UIActivityViewController(activityItems: [message], applicationActivities: nil)
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        if let root = scenes.first?.keyWindow?.rootViewController {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            top.present(activity, animated: true)
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
