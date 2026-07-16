import SwiftUI

/// A compact profile for a REAL online pilot: alias, balloon, flag, category,
/// approximate remaining time, and Crew actions. Shows nothing personal.
/// Decorative pilots never open this sheet.
struct PilotProfileSheet: View {
    let pilot: OnlinePilot
    @EnvironmentObject private var online: FocusOnlineModel
    @EnvironmentObject private var appModel: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var note: String?
    @State private var busy = false
    @State private var showReport = false
    @State private var showBlock = false

    /// Closed set of report reasons — no free text, no personal data.
    private let reportReasons = ["Inappropriate alias", "Harassment or bullying",
                                 "Spam", "Something else"]

    var body: some View {
        ZStack {
            AppBackground().ignoresSafeArea()
            VStack(spacing: AppSpacing.md) {
                Capsule().fill(.white.opacity(0.2)).frame(width: 40, height: 4).padding(.top, 10)
                BalloonView(height: 96, showBurner: false, showGlow: true,
                            skin: BalloonSkin.skin(id: pilot.balloonSkinID))
                    .padding(.top, AppSpacing.sm)
                HStack(spacing: 6) {
                    Text(pilot.displayName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)
                    if let cc = pilot.countryCode { Text(flagEmoji(cc)) }
                }
                HStack(spacing: 8) {
                    label(pilot.focusCategory, icon: "target")
                    label(pilot.isPaused ? "Paused" : pilot.remainingLabel, icon: "timer")
                }
                if let note {
                    Text(note).font(AppTypography.caption).foregroundStyle(AppColors.textSecondary)
                }
                VStack(spacing: AppSpacing.sm) {
                    if let status = online.requestStatus(for: pilot.id) {
                        Text(status)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(AppColors.gold)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .glassBackground(cornerRadius: AppSpacing.pillRadius, tintOpacity: 0.18,
                                             shadowRadius: 4, shadowY: 2)
                    } else if pilot.allowsFriendRequest {
                        AppPrimaryButton(title: busy ? "Sending…" : "Add to Crew", systemImage: "person.badge.plus") {
                            guard !busy else { return }
                            busy = true
                            appModel.tapFeedback()
                            Task { @MainActor in
                                note = await online.sendFriendRequest(to: pilot)
                                busy = false
                                if note == nil { note = "Crew request sent." }
                            }
                        }
                    }
                    HStack(spacing: AppSpacing.lg) {
                        Button("Hide this pilot") {
                            appModel.tapFeedback()
                            appModel.hidePilot(pilot.id)
                            dismiss()
                        }
                        .foregroundStyle(AppColors.textTertiary)
                        Button("Block") {
                            appModel.tapFeedback()
                            showBlock = true
                        }
                        .foregroundStyle(AppColors.danger.opacity(0.85))
                        Button("Report") {
                            appModel.tapFeedback()
                            showReport = true
                        }
                        .foregroundStyle(AppColors.danger.opacity(0.85))
                    }
                    .font(AppTypography.callout)
                }
                .padding(.horizontal, AppSpacing.screen)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.hidden)
        .confirmationDialog("Block this pilot?", isPresented: $showBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                appModel.tapFeedback()
                Task { @MainActor in
                    let err = await online.blockPilot(pilot)
                    if err == nil {
                        appModel.hidePilot(pilot.id)
                        dismiss()
                    } else {
                        note = err
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see each other in public Skies, and they can't send you requests or join your rooms.")
        }
        .confirmationDialog("Report this pilot?", isPresented: $showReport, titleVisibility: .visible) {
            ForEach(reportReasons, id: \.self) { reason in
                Button(reason, role: .destructive) {
                    appModel.tapFeedback()
                    Task { @MainActor in
                        let err = await online.reportPilot(pilot, reason: reason)
                        note = err ?? "Thanks — our team will review this pilot."
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Reports are anonymous and reviewed by our team. Only this pilot's anonymous ID and your chosen reason are sent — never any personal details.")
        }
    }

    private func label(_ text: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.system(size: 12.5, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(AppColors.textSecondary)
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(.white.opacity(0.08)))
    }
}

/// A country code ("US") → flag emoji.
func flagEmoji(_ countryCode: String) -> String {
    countryCode.uppercased().unicodeScalars.reduce(into: "") { result, scalar in
        if let flag = UnicodeScalar(127397 + scalar.value) { result.unicodeScalars.append(flag) }
    }
}
