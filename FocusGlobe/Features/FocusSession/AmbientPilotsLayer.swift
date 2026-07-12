import Foundation
import SwiftUI

/// Fellow balloons sharing the Sky during a flight — quiet, far away, drifting
/// naturally at different depths so the Sky never feels lonely. Hidden entirely
/// when the pilot chooses a solo flight.
///
/// HONESTY: until the presence backend ships (`SkyPresenceService`), these are
/// **ambient** travellers, deterministically seeded per Sky + session. They are
/// never presented as real people: in production the info bubble shows an
/// anonymous "Pilot" with an ambient focus time; sample display names/flags
/// exist only in DEBUG builds for design work. When real presence arrives, this
/// layer swaps its data source 1:1.
struct AmbientPilotsLayer: View {
    let skyID: String
    /// Pause-aware elapsed seconds — pilots hold still while paused.
    let elapsed: () -> Double
    var animated: Bool = true

    @State private var selectedPilot: Int? = nil

    private struct Pilot {
        let fx: Double        // base horizontal position (0…1)
        let fy: Double        // base vertical position (0…1)
        let depth: Double     // 0 far … 1 near (size + speed + opacity)
        let tintIndex: Int    // common cream most often, coloured sometimes
        let phase: Double
        let minutesLeft: Int  // ambient bubble time
        let nameIndex: Int
    }

    /// Common envelopes far outweigh rare ones (like real traffic would).
    private static let envelopes: [Color] = [
        Color(hex: 0xF4EFE4), Color(hex: 0xF4EFE4), Color(hex: 0xF4EFE4),
        Color(hex: 0xE8C4C8), Color(hex: 0xBFD0EC), Color(hex: 0xD8E6D4),
    ]

    #if DEBUG
    private static let sampleNames = ["Mia · 🇮🇹", "Leo · 🇫🇷", "Aiko · 🇯🇵", "Noah · 🇺🇸",
                                      "Lena · 🇩🇪", "Sofia · 🇪🇸", "Yuki · 🇯🇵", "Omar · 🇦🇪"]
    #endif

    private var pilots: [Pilot] {
        var h: UInt64 = 0xB111
        for u in skyID.unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        var rng = SeededRNG(seed: h)
        var list: [Pilot] = []
        for _ in 0..<12 {
            list.append(Pilot(fx: 0.06 + rng.unit() * 0.88,
                              fy: 0.08 + rng.unit() * 0.68,
                              depth: rng.unit(),
                              tintIndex: Int(rng.unit() * Double(Self.envelopes.count)) % Self.envelopes.count,
                              phase: rng.unit() * 6.28,
                              minutesLeft: 5 + Int(rng.unit() * 50),
                              nameIndex: Int(rng.unit() * 8)))
        }
        return list
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            TimelineView(.animation(minimumInterval: animated ? 1.0 / 20.0 : 5.0)) { _ in
                // Motion rides the pause-aware flight clock: pilots hold still
                // whenever the session is paused, exactly like the Sky.
                let t = animated ? elapsed() : 0
                ZStack {
                    ForEach(Array(pilots.enumerated()), id: \.offset) { index, pilot in
                        pilotView(pilot, index: index, W: W, H: H, t: t)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pilotView(_ p: Pilot, index: Int, W: CGFloat, H: CGFloat, t: Double) -> some View {
        // Slow vertical drift with a seamless wrap + a gentle sway: pilots move
        // with the world's air, never pinned like UI.
        let span = 1.3
        let drift = (p.fy + t * (0.004 + p.depth * 0.006) + p.phase * 0.01)
            .truncatingRemainder(dividingBy: span)
        let y = CGFloat(drift - 0.15) * H
        let sway = CGFloat(Foundation.sin(t * (0.16 + p.depth * 0.12) + p.phase)) * (6 + CGFloat(p.depth) * 8)
        let x = CGFloat(p.fx) * W + sway
        let size = CGFloat(13 + p.depth * 13)
        let alpha = 0.32 + p.depth * 0.34

        ZStack(alignment: .bottom) {
            if selectedPilot == index {
                pilotBubble(p)
                    .offset(y: -size - 12)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            MiniBalloonView(size: size, envelope: Self.envelopes[p.tintIndex], showGlow: false)
                .opacity(alpha)
        }
        .position(x: x, y: y)
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                selectedPilot = (selectedPilot == index) ? nil : index
            }
        }
    }

    private func pilotBubble(_ p: Pilot) -> some View {
        VStack(spacing: 2) {
            Text(bubbleName(p))
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("\(p.minutesLeft) min left")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().fill(Color.black.opacity(0.25)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .fixedSize()
    }

    private func bubbleName(_ p: Pilot) -> String {
        #if DEBUG
        return Self.sampleNames[p.nameIndex % Self.sampleNames.count]
        #else
        return "Pilot"
        #endif
    }
}
