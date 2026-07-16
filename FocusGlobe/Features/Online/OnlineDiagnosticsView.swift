#if DEBUG
import SwiftUI

/// DEBUG-only online diagnostics (never compiled into Release). Supabase-era:
/// shows the authoritative OnlineState, account, room pipeline state and the
/// EXACT last backend error, plus on-device reproduction actions.
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
                    group("Backend", SupabaseConfig.projectURL?.host ?? "NOT CONFIGURED")
                    group("Configured", "\(SupabaseConfig.isConfigured)")
                    group("State", String(describing: online.availability))
                    group("userID", online.shortPublicID)
                    group("Alias", online.profile?.displayName ?? "—")
                    group("Discoverable", "\(online.profile?.isDiscoverable ?? false)")
                    group("Flight mode", online.flightMode.rawValue)
                    group("Last pilot fetch", online.lastPilotFetchAt?.formatted() ?? "—")
                    group("Real pilots", "\(online.realPilotCount)")
                    group("Pending room", online.pendingRoom?.id.prefix(8).description ?? "—")
                    group("Room state", online.roomStateSummary)
                    group("Owned rooms", "\(online.ownedRooms.count)")
                    group("Joined rooms", "\(online.joinedRooms.count)")
                    group("Incoming requests", "\(online.incomingRequests.count)")
                    group("Last error", online.lastErrorCategory ?? "—")
                    if let detail = online.lastRoomErrorDetail {
                        // The EXACT backend breakdown from the last failure —
                        // the real error, never a generic message.
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Last error (exact)")
                                .font(AppTypography.caption).foregroundStyle(AppColors.textTertiary)
                            Text(detail)
                                .font(.system(size: 10.5, design: .monospaced))
                                .foregroundStyle(AppColors.gold)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .glassBackground(cornerRadius: 10, tintOpacity: 0.14, shadowRadius: 2, shadowY: 1)
                    }
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
            // Reproduce room creation on-device and print the EXACT outcome.
            row("Create test private room") {
                if let until = online.roomThrottledUntil {
                    log.append("throttled: try again in \(max(0, Int(until.timeIntervalSinceNow)))s (\(online.roomStateSummary))")
                    return
                }
                let room = await online.requestPrivateFlightRoom(skyID: appModel.selectedSky.id,
                                                                 title: "Diagnostic Room")
                if let room, room.shareURL != nil {
                    log.append("room OK: \(room.id.prefix(8)) url=yes")
                } else {
                    log.append("room FAILED: \(online.roomStateSummary) | \(online.lastRoomErrorDetail ?? online.lastErrorCategory ?? "unknown")")
                }
            }
            row("Refresh Online status") { await online.refreshAvailability(); log.append("state: \(online.availability)") }
            row("Fetch campaign progress") {
                await online.refreshCampaignProgress(skyID: appModel.selectedSky.id, required: 3)
                log.append("campaign \(appModel.selectedSky.id): \(online.campaignProgress(skyID: appModel.selectedSky.id))")
            }
            row("Refresh social") { await online.refreshSocial(); log.append("crew: \(online.crew.count)") }
            row("Refresh rooms") { await online.refreshRooms(); log.append("rooms: \(online.ownedRooms.count)/\(online.joinedRooms.count)") }
            row("Recreate profile") { await online.ensureIdentityAndProfile(); log.append("profile: \(online.profile?.displayName ?? "nil")") }
            row("Close my rooms (cleanup)") {
                let n = await online.debugPurgeOwnedRooms()
                log.append("closed \(n) owned room(s); state \(online.roomStateSummary)")
            }
            row("Sign out") { await online.signOut(); log.append("signed out; state: \(online.availability)") }
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
