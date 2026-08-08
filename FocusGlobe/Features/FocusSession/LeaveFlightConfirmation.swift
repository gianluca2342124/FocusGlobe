import SwiftUI

/// The confirmation shown when a pilot holds the close control mid-flight.
///
/// ## It does not pause anything
///
/// This is presentation state and nothing else. The timer, the audio, the online
/// heartbeat, the remote pilots and the living Sky all keep running behind it —
/// no pause RPC is sent and no local pause flag is touched. That is deliberate:
/// a confirmation that silently stopped the clock would let anyone bank free
/// minutes by opening it, and would make "are you sure?" a lie about the state
/// of the flight. It is drawn as an OVERLAY rather than a sheet for the same
/// reason — the flight stays visible and alive underneath, so the pilot can see
/// exactly what they are about to walk away from.
///
/// Only `onLeave` abandons the journey, and it calls the one canonical path.
struct LeaveFlightConfirmation: View {
    /// Real focused seconds banked so far — the basis for every claim here.
    let focusedSeconds: Int
    /// Online flights additionally cost the pilot their place in the Sky, which
    /// is the one loss row the other modes do not have.
    let isOnline: Bool
    let isInfinite: Bool
    let onKeepFlying: () -> Void
    let onLeave: () -> Void

    @EnvironmentObject private var appModel: AppModel
    @Environment(\.focusViewport) private var viewport
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: What is actually at stake

    /// A flight only earns anything at all once it clears the five-minute gate.
    /// Below it there are genuinely no coins to lose, and saying otherwise would
    /// be inventing a loss to raise the stakes.
    private var isEligible: Bool { focusedSeconds >= FocusConsistency.qualifyingSeconds }

    /// The real reward, including the PRO multiplier — quoted from the model, so
    /// a PRO pilot is told the doubled figure they would actually bank.
    private var coinsAtStake: Int { appModel.projectedJourneyCoins(focusedSeconds: focusedSeconds) }

    /// Nothing is resumable after this. Leaving CLEARS the snapshot rather than
    /// writing one, for Solo exactly as for Online, so there is no mode in which
    /// a resume may be offered here. The property is gone with the promise.

    private var explanation: String {
        if isOnline {
            return "This flight’s progress and rewards will be lost, and you’ll leave the Sky you’re flying in."
        }
        if isInfinite {
            return "This open-ended flight will end here. Its progress and rewards will be lost."
        }
        return "This flight’s progress and rewards will be lost."
    }

    private var lossRows: [(icon: String, title: String, detail: String)] {
        var rows: [(String, String, String)] = [
            ("timer", "Flight progress", Formatters.durationLabel(minutes: focusedSeconds / 60)),
        ]
        // Only claim coins when there are genuinely coins to claim.
        if isEligible, coinsAtStake > 0 {
            rows.append(("circle.hexagongrid.fill", "Up to \(coinsAtStake) Coins",
                         appModel.isPro ? "2× PRO" : "Unbanked"))
        }
        rows.append(("target", "Mission credit", "Today’s goals"))
        rows.append(("flame.fill", "Streak progress", "Grows on landing"))
        if isOnline {
            rows.append(("person.2.fill", "Your place in the Sky", "You’ll leave the room"))
        }
        return rows
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // Restrained dim. The Sky and the other pilots stay legible — this is
            // the thing being weighed up, so it must not be hidden.
            Color.black.opacity(0.52)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                // Tapping outside is the SAFE action. A stray tap must never be
                // able to abandon a flight.
                .onTapGesture(perform: onKeepFlying)

            card
                .frame(maxWidth: 380)
                .padding(.horizontal, viewport.pagePadding)
        }
        .transition(reduceMotion
                    ? .opacity
                    : .opacity.combined(with: .scale(scale: 0.96)))
    }

    private var card: some View {
        VStack(spacing: AppSpacing.md) {
            mark

            VStack(spacing: 6) {
                Text("Leave this flight?")
                    .font(.system(size: viewport.isCompact ? 22 : 25, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)

                Text(explanation)
                    .font(AppTypography.callout)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            lossSummary

            VStack(spacing: 9) {
                // The safe choice is the prominent one. Leaving is available and
                // unmistakably destructive, but it is not the default gesture.
                Button(action: onKeepFlying) {
                    Text("Keep Focusing")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(ProBrand.primaryButton))
                }
                .buttonStyle(SoftPressStyle())

                Button(role: .destructive, action: onLeave) {
                    Text("Leave Flight")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColors.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                        .contentShape(Rectangle())
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityHint("Ends this flight now. Its progress and rewards are not kept.")
            }
        }
        .padding(AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(AppColors.backgroundTop)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(AppColors.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 30, y: 16)
        // Read top to bottom: what is being asked, then what it costs, then the
        // two ways out.
        .accessibilityElement(children: .contain)
    }

    /// A balloon losing height — the loss, drawn rather than described. Static:
    /// a confirmation is not the place for something moving.
    private var mark: some View {
        ZStack {
            Circle()
                .fill(AppColors.danger.opacity(0.12))
                .frame(width: 76, height: 76)
            Image(systemName: "arrow.down.right")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(AppColors.danger.opacity(0.85))
                .offset(x: 24, y: 20)
            BalloonView(height: 46, showBurner: false, showGlow: false,
                        skin: appModel.selectedSkin)
                .rotationEffect(.degrees(-12))
                .offset(x: -4, y: -3)
        }
        .frame(height: 82)
        .accessibilityHidden(true)
    }

    /// Small rows rather than one dense paragraph — each loss is a separate fact
    /// and reads faster as one.
    private var lossSummary: some View {
        VStack(spacing: 0) {
            ForEach(Array(lossRows.enumerated()), id: \.offset) { index, row in
                if index > 0 {
                    Rectangle().fill(AppColors.hairline).frame(height: 1)
                }
                HStack(spacing: 10) {
                    Image(systemName: row.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.gold)
                        .frame(width: 20)
                    Text(LocalizedStringKey(row.title))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer(minLength: 8)
                    Text(LocalizedStringKey(row.detail))
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(AppColors.textTertiary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .accessibilityElement(children: .combine)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.textPrimary.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppColors.hairline, lineWidth: 1)
        )
    }
}
