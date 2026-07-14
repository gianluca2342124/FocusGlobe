import SwiftUI

/// Create a private focus room for the selected Sky, then jump straight into
/// its lobby to invite friends.
struct CreateRoomView: View {
    let skyID: String
    var onCreated: (FocusRoom) -> Void
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var title = "Focus together"
    @State private var busy = false

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                Capsule().fill(.white.opacity(0.2)).frame(width: 40, height: 4).padding(.top, 10)
                Text("Create Private Flight")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
                TextField("e.g. Study sprint", text: $title)
                    .font(AppTypography.body)
                    .padding(AppSpacing.md)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.08)))
                    .foregroundStyle(AppColors.textPrimary)
                AppPrimaryButton(title: busy ? "Creating…" : "Create Room", systemImage: "person.2.fill") {
                    guard !busy else { return }
                    busy = true
                    appModel.tapFeedback()
                    Task { @MainActor in
                        if let invitation = await online.createRoom(skyID: skyID, title: title.isEmpty ? "Focus together" : title) {
                            onCreated(invitation.room)
                            dismiss()
                        }
                        busy = false
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppSpacing.screen)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.fraction(0.42)])
    }
}
