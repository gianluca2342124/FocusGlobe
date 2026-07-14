#if DEBUG
import SwiftUI

/// DEBUG-only online diagnostics (never compiled into Release).
struct OnlineDiagnosticsView: View {
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @State private var log: [String] = []

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Online Diagnostics").font(AppTypography.hero).foregroundStyle(AppColors.textPrimary)
                    group("Container", CloudKitConfig.containerIdentifier)
                    group("Account", String(describing: online.availability))
                    group("publicID", online.shortPublicID)
                    group("Profile", online.profile?.displayName ?? "—")
                    group("Discoverable", "\(online.profile?.isDiscoverable ?? false)")
                    group("Flight mode", online.flightMode.rawValue)
                    group("Last pilot fetch", online.lastPilotFetchAt?.formatted() ?? "—")
                    group("Real pilots", "\(online.realPilotCount)")
                    group("Pending room", online.pendingRoom?.id.prefix(8).description ?? "—")
                    group("Owned rooms", "\(online.ownedRooms.count)")
                    group("Joined rooms", "\(online.joinedRooms.count)")
                    group("Incoming requests", "\(online.incomingRequests.count)")
                    group("Last error", online.lastErrorCategory ?? "—")
                    actions
                    ForEach(log, id: \.self) { line in
                        Text(line).font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                }
                .padding(AppSpacing.screen)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            row("Refresh Cloud status") { await online.refreshAvailability(); log.append("status: \(online.availability)") }
            row("Fetch current Sky pilots") {
                await online.refreshCampaignProgress(skyID: appModel.selectedSky.id, required: 3)
                log.append("campaign \(appModel.selectedSky.id): \(online.campaignProgress(skyID: appModel.selectedSky.id))")
            }
            row("Refresh social") { await online.refreshSocial(); log.append("crew: \(online.crew.count)") }
            row("Refresh rooms") { await online.refreshRooms(); log.append("rooms: \(online.ownedRooms.count)/\(online.joinedRooms.count)") }
            row("Recreate public profile") { await online.ensureIdentityAndProfile(); log.append("profile ok") }
            row("Clear online cache") { OnlineCache.resetForAccountChange(); log.append("cache cleared") }
        }
    }

    private func row(_ title: String, _ action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.gold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .glassBackground(cornerRadius: 12, tintOpacity: 0.18, shadowRadius: 3, shadowY: 2)
        }
        .buttonStyle(SoftPressStyle())
    }

    private func group(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
            Spacer()
            Text(value).font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}
#endif
