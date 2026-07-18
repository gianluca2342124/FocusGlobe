import SwiftUI

/// The short, premium "pilots are joining" moment shown ONLY for Online
/// journeys, between the Boarding Pass cut and the visible flight. It is an
/// overlay inside the journey cover (the flight initialises beneath it), so it
/// can never deadlock navigation: it always completes — after real pilots are
/// fetched, after the minimum display beat, or after a hard timeout.
///
/// HONESTY: every row is a REAL pilot fetched from the live Sky (alias, skin,
/// country when shared). Nothing is fabricated, and no fake room capacity is
/// implied — the count line reads "Connecting with N pilots" from actual data,
/// or a neutral line when the Sky is quiet.
struct OnlineJoiningView: View {
    enum Mode: Equatable {
        case global(FocusSky?)
        case privateGuest(hostAlias: String?)
    }

    let mode: Mode
    let onDone: () -> Void
    @EnvironmentObject private var online: FocusOnlineModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pilots: [OnlinePilot] = []
    @State private var visibleRows = 0
    @State private var fetched = false
    @State private var finished = false

    private var sky: FocusSky? {
        if case .global(let s) = mode { return s }
        return nil
    }

    var body: some View {
        ZStack {
            // The selected Sky's own atmosphere as the ground — never a generic
            // spinner screen.
            LinearGradient(colors: (sky?.paletteColors ?? [AppColors.neutralBase, AppColors.neutralDeep]),
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            LinearGradient(colors: [.black.opacity(0.30), .clear, .black.opacity(0.45)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: AppSpacing.lg) {
                Spacer()
                BalloonView(height: 96, showBurner: false, showGlow: false,
                            skin: BalloonSkin.skin(id: nil))
                VStack(spacing: 6) {
                    Text(headline)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text(subline)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                        .contentTransition(.numericText())
                }
                pilotRows
                Spacer()
                ProgressView()
                    .tint(.white.opacity(0.8))
                    .padding(.bottom, Layout.pad(40, 56))
            }
            .padding(.horizontal, AppSpacing.screen)
        }
        .task { await run() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(headline)
    }

    private var headline: String {
        switch mode {
        case .global:                       return "Joining the Global Sky"
        case .privateGuest(let host):
            if let host, !host.isEmpty { return "Joining \(host)'s Flight" }
            return "Joining the Flight"
        }
    }

    private var subline: String {
        if case .privateGuest = mode { return "Synchronizing with the crew…" }
        if !fetched { return "Connecting…" }
        return pilots.isEmpty ? "A quiet sky today — clear air ahead"
                              : "Connecting with \(pilots.count) pilot\(pilots.count == 1 ? "" : "s")"
    }

    /// Up to five REAL pilots, appearing one by one as the connection settles.
    private var pilotRows: some View {
        VStack(spacing: AppSpacing.xs) {
            ForEach(Array(pilots.prefix(5).enumerated()), id: \.element.id) { index, pilot in
                if index < visibleRows {
                    HStack(spacing: 10) {
                        BalloonView(height: 30, showBurner: false, showGlow: false,
                                    skin: BalloonSkin.skin(id: pilot.balloonSkinID))
                        Text(pilot.displayName + (pilot.countryCode.map { " " + flagEmoji($0) } ?? ""))
                            .font(.system(size: 14.5, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        if !pilot.focusCategory.isEmpty {
                            Text(pilot.focusCategory)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.65))
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .overlay(Capsule().fill(Color.black.opacity(0.18)))
                    .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                    .transition(reduceMotion ? .opacity
                                            : .opacity.combined(with: .move(edge: .bottom)))
                }
            }
        }
        .frame(maxWidth: 420)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: visibleRows)
    }

    /// Fetch real pilots + pace the reveal; ALWAYS completes (min beat 1.4 s,
    /// hard cap 4 s) so the flight is never blocked behind this screen.
    private func run() async {
        async let minimum: Void = { try? await Task.sleep(nanoseconds: 1_400_000_000) }()
        if case .global(let sky) = mode, let sky {
            // Hard 4 s cap: a slow network can shorten the pilot list, never
            // extend this screen.
            let fetchTask = Task { await online.previewPilots(skyID: sky.id) }
            let watchdog = Task { try? await Task.sleep(nanoseconds: 4_000_000_000); fetchTask.cancel() }
            let found = await fetchTask.value
            watchdog.cancel()
            pilots = found
            fetched = true
            for i in 0...min(5, found.count) {
                visibleRows = i
                try? await Task.sleep(nanoseconds: 180_000_000)
            }
        } else {
            fetched = true
        }
        _ = await minimum
        complete()
    }

    private func complete() {
        guard !finished else { return }
        finished = true
        onDone()
    }
}
