import SwiftUI

/// A compact row/details for a room listed on the Friends page — open its
/// lobby, or leave/close it.
struct RoomDetailsView: View {
    let room: FocusRoom
    var onOpenLobby: (FocusRoom) -> Void
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel

    private var sky: FocusSky { FocusSky.byID(room.skyID) ?? .defaultFree }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: room.status == .active ? "airplane.departure" : "person.2.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppColors.gold)
                .frame(width: 36, height: 36)
                .background(Circle().fill(AppColors.gold.opacity(0.14)))
            VStack(alignment: .leading, spacing: 1) {
                Text(room.title)
                    .font(.system(size: 15, weight: .bold, design: .default))
                    .foregroundStyle(AppColors.textPrimary)
                Text("\(sky.name) · \(room.isOwned ? "your room" : "invited") · \(room.status == .active ? "in flight" : "lobby")")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.textTertiary)
            }
            Spacer()
            Button {
                appModel.tapFeedback()
                onOpenLobby(room)
            } label: {
                Text("Open")
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .foregroundStyle(Color(hex: 0x14120E))
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Capsule().fill(AppColors.gold))
            }
            .buttonStyle(SoftPressStyle())
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 10)
        .glassBackground(cornerRadius: 16, tintOpacity: 0.2, shadowRadius: 5, shadowY: 3)
    }
}
