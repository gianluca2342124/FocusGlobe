import Foundation
import SwiftUI

/// Fellow balloons sharing the Sky during a flight — quiet, far away, **floating**
/// calmly (never falling), each holding roughly its own patch of sky with a
/// gentle bob + sway. Hidden entirely when the pilot chooses a solo flight.
///
/// HONESTY: these are local **decorative** travellers that fill the sky's
/// visual capacity — deterministically seeded per Sky so a session feels
/// stable but varied. They never exist in the backend and are never presented
/// as verified real-time users; REAL pilots come exclusively from
/// `FocusOnlineModel.realPilots` (Supabase) and render above this layer.
struct AmbientPilotsLayer: View {
    let skyID: String
    /// Pause-aware elapsed seconds — pilots hold still while paused.
    let elapsed: () -> Double
    var animated: Bool = true
    /// REAL online pilots (public Sky or private room). They render first, at
    /// the exact same size/behaviour as decorative ones; decorative ambient
    /// pilots then fill the remaining visual capacity so the Sky stays alive.
    var realPilots: [OnlinePilot] = []
    /// Private-room participants show their identity bubble persistently; public
    /// ambient pilots reveal it on tap.
    var roomMode: Bool = false
    /// Compact contextual actions on a real pilot (long-press / context menu).
    /// A deliberate "View profile" may still open a small sheet via onSelectReal.
    var onSelectReal: ((OnlinePilot) -> Void)? = nil
    var onAddFriend: ((OnlinePilot) -> Void)? = nil
    var onHide: ((OnlinePilot) -> Void)? = nil
    var onBlock: ((OnlinePilot) -> Void)? = nil
    var onReport: ((OnlinePilot) -> Void)? = nil

    @State private var selectedPilot: Int? = nil

    private struct Pilot {
        let fx: Double        // stable horizontal position (0…1)
        let fy: Double        // stable vertical position (0…1)
        let depth: Double     // 0 far … 1 near (size + speed + opacity)
        let phase: Double
        let minutesLeft: Int
        let profileIndex: Int // into PilotDirectory (unique per flight)
        let skin: BalloonSkin
    }

    /// How many fellow balloons share the Sky — a lively population (every
    /// pilot renders at the user balloon's exact size; spacing rules below keep
    /// them from clumping or crowding the user).
    private static let count = 10

    /// Weighted skin bag: the default/common skins dominate; rare/premium skins
    /// appear seldom (like real traffic), never one-of-each.
    private static let skinBag: [BalloonSkin] = {
        let byID: (String) -> BalloonSkin? = { id in BalloonSkin.all.first { $0.id == id } }
        var bag: [BalloonSkin] = []
        func add(_ id: String, _ n: Int) { if let s = byID(id) { bag += Array(repeating: s, count: n) } }
        add("default", 8); add("cloudy", 3); add("balloon", 3); add("marshmallow", 2)
        add("emoji", 1); add("moon", 1); add("galaxy", 1); add("sky-pilot", 1)
        return bag.isEmpty ? [BalloonSkin.default] : bag
    }()

    private var pilots: [Pilot] {
        var h: UInt64 = 0xB111
        for u in skyID.unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        var rng = SeededRNG(seed: h)
        // Unique profiles this flight: shuffle the directory deterministically.
        var indices = Array(0..<PilotDirectory.all.count)
        for i in stride(from: indices.count - 1, to: 0, by: -1) {
            let j = Int(rng.unit() * Double(i + 1))
            indices.swapAt(i, min(i, max(0, j)))
        }
        var list: [Pilot] = []
        for k in 0..<min(Self.count, indices.count) {
            let skin = Self.skinBag[Int(rng.unit() * Double(Self.skinBag.count)) % Self.skinBag.count]
            // Seeded position with simple constraints: keep a horizontal gap from
            // already-placed pilots and stay out of the user balloon's central
            // column, so same-size pilots never clump or hide the hero.
            var fx = 0.06 + rng.unit() * 0.88
            var fy = 0.08 + rng.unit() * 0.52
            var attempts = 0
            while attempts < 8 {
                let clashesCentre = fx > 0.40 && fx < 0.60 && fy > 0.30
                let clashesPilot = list.contains { abs($0.fx - fx) < 0.13 && abs($0.fy - fy) < 0.12 }
                if !clashesCentre && !clashesPilot { break }
                fx = 0.06 + rng.unit() * 0.88
                fy = 0.08 + rng.unit() * 0.52
                attempts += 1
            }
            list.append(Pilot(fx: fx,
                              fy: fy,
                              depth: rng.unit(),
                              phase: rng.unit() * 6.28,
                              minutesLeft: 3 + Int(rng.unit() * 55),
                              profileIndex: indices[k],
                              skin: skin))
        }
        return list
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            // Visual capacity: real pilots first, then decorative fill.
            let capacity = min(H, W) > 700 ? 14 : Self.count
            let real = Array(realPilots.prefix(capacity))
            let fill = Array(pilots.prefix(max(0, capacity - real.count)))
            TimelineView(.animation(minimumInterval: animated ? 1.0 / 20.0 : 5.0)) { _ in
                let t = animated ? elapsed() : 0
                ZStack {
                    ForEach(Array(real.enumerated()), id: \.element.id) { index, pilot in
                        realPilotView(pilot, index: index, W: W, H: H, t: t)
                    }
                    ForEach(Array(fill.enumerated()), id: \.offset) { index, pilot in
                        pilotView(pilot, index: index + real.count, W: W, H: H, t: t)
                    }
                }
            }
        }
        // Bubbles fade themselves out after ~3 seconds.
        .task(id: selectedPilot) {
            guard selectedPilot != nil else { return }
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(.easeOut(duration: 0.3)) { selectedPilot = nil }
        }
    }

    @ViewBuilder
    private func pilotView(_ p: Pilot, index: Int, W: CGFloat, H: CGFloat, t: Double) -> some View {
        // A gentle bob + sway around a STABLE position — floating like a pilot,
        // never a continuous downward scroll.
        let bob = CGFloat(Foundation.sin(t * (0.2 + p.depth * 0.14) + p.phase)) * (7 + CGFloat(p.depth) * 9)
        let sway = CGFloat(Foundation.sin(t * (0.13 + p.depth * 0.1) + p.phase * 1.3)) * (6 + CGFloat(p.depth) * 8)
        let x = CGFloat(p.fx) * W + sway
        let y = CGFloat(p.fy) * H + bob
        // Slightly smaller than the central user balloon (~82% of its cruising
        // size) so the hero always reads as the largest, never scaled down by
        // depth beyond that. Depth reads through opacity, keeping the user
        // balloon dominant via full size + full opacity + glow.
        let size = max(38, min(52, H * 0.07)) * 0.82
        let alpha = 0.18 + p.depth * 0.16   // 0.18…0.34

        // Decorative pilots are purely ambient: no name, flag, timer or tap —
        // only a REAL online pilot (realPilotView) is interactive/identifiable.
        BalloonView(height: size, showBurner: false, showGlow: false, skin: p.skin)
            .opacity(alpha)
            .position(x: x, y: y)
            .allowsHitTesting(false)
    }

    /// Deterministic per-pilot seed: hash(publicID + sessionID + skyID). Kept
    /// out of the view builder so the loop isn't imperative control flow inside
    /// `@ViewBuilder` (the position it yields is stable for the whole session
    /// and identical in Cabin View).
    private func stablePilotSeed(for pilot: OnlinePilot) -> UInt64 {
        var h: UInt64 = 0x9E37
        for u in (pilot.id + pilot.sessionID + skyID).unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        return h
    }

    /// A REAL online pilot: same size token and float behaviour as everyone
    /// else; position seeded from `stablePilotSeed` so it is stable for the
    /// whole session and identical in Cabin View.
    private func realPilotView(_ pilot: OnlinePilot, index: Int, W: CGFloat, H: CGFloat, t: Double) -> some View {
        var rng = SeededRNG(seed: stablePilotSeed(for: pilot))
        let fx = 0.08 + rng.unit() * 0.84
        let fy = 0.10 + rng.unit() * 0.5
        let phase = rng.unit() * 6.28
        let bob = CGFloat(Foundation.sin(t * 0.22 + phase)) * 9
        let sway = CGFloat(Foundation.sin(t * 0.14 + phase * 1.3)) * 7
        // Same ~82% of the hero's cruising size as decorative pilots — never
        // larger than the user balloon.
        let size = max(38, min(52, H * 0.07)) * 0.82
        // Private-room participants read as identified crew: brighter, and their
        // bubble stays up. Public ambient pilots reveal a bubble on tap only.
        let showBubble = roomMode || selectedRealID == pilot.id
        let baseOpacity = roomMode ? 0.9 : (selectedRealID == pilot.id ? 0.48 : (pilot.isPaused ? 0.20 : 0.32))
        return ZStack(alignment: .bottom) {
            if showBubble {
                realBubble(pilot)
                    .offset(y: -size - 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            BalloonView(height: size, showBurner: false, showGlow: roomMode,
                        skin: BalloonSkin.skin(id: pilot.balloonSkinID))
                .opacity(baseOpacity)
        }
        .position(x: CGFloat(fx) * W + sway, y: CGFloat(fy) * H + bob)
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
                selectedRealID = selectedRealID == pilot.id ? nil : pilot.id
            }
        }
        // Compact contextual actions — no giant modal on a normal tap.
        .contextMenu {
            if let onAddFriend { Button { onAddFriend(pilot) } label: { Label("Add Friend", systemImage: "person.badge.plus") } }
            if let onSelectReal { Button { onSelectReal(pilot) } label: { Label("View profile", systemImage: "person.crop.circle") } }
            if let onHide { Button { onHide(pilot) } label: { Label("Hide this pilot", systemImage: "eye.slash") } }
            if let onBlock { Button(role: .destructive) { onBlock(pilot) } label: { Label("Block", systemImage: "hand.raised") } }
            if let onReport { Button(role: .destructive) { onReport(pilot) } label: { Label("Report", systemImage: "flag") } }
        }
    }

    @State private var selectedRealID: String? = nil

    private func realBubble(_ pilot: OnlinePilot) -> some View {
        // Alias + synchronized remaining time. The time line is shown ONLY when
        // the pilot has a real live session (never a fabricated "Focus" pill).
        VStack(spacing: 2) {
            Text("\(pilot.displayName)\(pilot.countryCode.map { " " + flagEmoji($0) } ?? "")")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            if !pilot.remainingLabel.isEmpty {
                Text(pilot.remainingLabel)
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().fill(Color.black.opacity(0.25)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .fixedSize()
    }

    private func appTapSelect(_ index: Int) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) {
            selectedPilot = (selectedPilot == index) ? nil : index
        }
    }

    private func pilotBubble(_ p: Pilot) -> some View {
        let profile = PilotDirectory.all[p.profileIndex % PilotDirectory.all.count]
        return VStack(spacing: 2) {
            Text("\(profile.handle) \(profile.flag)")
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
}

/// A local, **mock** directory of fellow pilots (handle + country flag). Clearly
/// placeholder data for ambient presence until the real backend lands — never
/// claimed as verified online users.
enum PilotDirectory {
    struct Profile { let handle: String; let flag: String; let country: String }

    static let all: [Profile] = [
        Profile(handle: "lina", flag: "🇸🇪", country: "Sweden"),
        Profile(handle: "mateo", flag: "🇦🇷", country: "Argentina"),
        Profile(handle: "noah_studies", flag: "🇺🇸", country: "USA"),
        Profile(handle: "sofia", flag: "🇪🇸", country: "Spain"),
        Profile(handle: "julia_focus", flag: "🇧🇷", country: "Brazil"),
        Profile(handle: "kenji", flag: "🇯🇵", country: "Japan"),
        Profile(handle: "amara", flag: "🇳🇬", country: "Nigeria"),
        Profile(handle: "leo", flag: "🇫🇷", country: "France"),
        Profile(handle: "clara", flag: "🇩🇪", country: "Germany"),
        Profile(handle: "nora", flag: "🇳🇴", country: "Norway"),
        Profile(handle: "studywithleo", flag: "🇮🇹", country: "Italy"),
        Profile(handle: "yuki", flag: "🇯🇵", country: "Japan"),
        Profile(handle: "ines", flag: "🇵🇹", country: "Portugal"),
        Profile(handle: "valen", flag: "🇨🇱", country: "Chile"),
        Profile(handle: "theo", flag: "🇬🇷", country: "Greece"),
        Profile(handle: "mia_reads", flag: "🇬🇧", country: "UK"),
        Profile(handle: "ari_focus", flag: "🇮🇱", country: "Israel"),
        Profile(handle: "hana", flag: "🇰🇷", country: "Korea"),
        Profile(handle: "diego", flag: "🇲🇽", country: "Mexico"),
        Profile(handle: "emma", flag: "🇨🇦", country: "Canada"),
        Profile(handle: "luca", flag: "🇮🇹", country: "Italy"),
        Profile(handle: "aya", flag: "🇪🇬", country: "Egypt"),
        Profile(handle: "finn", flag: "🇫🇮", country: "Finland"),
        Profile(handle: "priya", flag: "🇮🇳", country: "India"),
        Profile(handle: "oskar", flag: "🇵🇱", country: "Poland"),
        Profile(handle: "maya_studies", flag: "🇦🇺", country: "Australia"),
        Profile(handle: "tomas", flag: "🇨🇿", country: "Czechia"),
        Profile(handle: "sara", flag: "🇩🇰", country: "Denmark"),
        Profile(handle: "ravi", flag: "🇮🇳", country: "India"),
        Profile(handle: "elif", flag: "🇹🇷", country: "Türkiye"),
        Profile(handle: "bruno", flag: "🇧🇷", country: "Brazil"),
        Profile(handle: "nina", flag: "🇷🇸", country: "Serbia"),
        Profile(handle: "kai", flag: "🇳🇿", country: "New Zealand"),
        Profile(handle: "lea", flag: "🇨🇭", country: "Switzerland"),
        Profile(handle: "omar", flag: "🇦🇪", country: "UAE"),
        Profile(handle: "zoe", flag: "🇬🇷", country: "Greece"),
        Profile(handle: "matteo", flag: "🇮🇹", country: "Italy"),
        Profile(handle: "freya", flag: "🇮🇸", country: "Iceland"),
        Profile(handle: "santiago", flag: "🇨🇴", country: "Colombia"),
        Profile(handle: "ada", flag: "🇬🇧", country: "UK"),
        Profile(handle: "niko", flag: "🇬🇷", country: "Greece"),
        Profile(handle: "chiara", flag: "🇮🇹", country: "Italy"),
        Profile(handle: "hugo", flag: "🇫🇷", country: "France"),
        Profile(handle: "mei", flag: "🇸🇬", country: "Singapore"),
        Profile(handle: "jonas", flag: "🇩🇪", country: "Germany"),
        Profile(handle: "aria_focus", flag: "🇺🇸", country: "USA"),
        Profile(handle: "pablo", flag: "🇪🇸", country: "Spain"),
        Profile(handle: "isla", flag: "🇮🇪", country: "Ireland"),
        Profile(handle: "ryo", flag: "🇯🇵", country: "Japan"),
        Profile(handle: "vera", flag: "🇳🇱", country: "Netherlands"),
        Profile(handle: "andres", flag: "🇵🇪", country: "Peru"),
        Profile(handle: "lotte", flag: "🇳🇱", country: "Netherlands"),
        Profile(handle: "sami", flag: "🇫🇮", country: "Finland"),
        Profile(handle: "gabriela", flag: "🇧🇷", country: "Brazil"),
        Profile(handle: "erik", flag: "🇸🇪", country: "Sweden"),
        Profile(handle: "noor", flag: "🇲🇦", country: "Morocco"),
        Profile(handle: "dani", flag: "🇪🇸", country: "Spain"),
        Profile(handle: "keira", flag: "🇮🇪", country: "Ireland"),
        Profile(handle: "tobias", flag: "🇦🇹", country: "Austria"),
        Profile(handle: "lucia", flag: "🇮🇹", country: "Italy"),
        Profile(handle: "wei", flag: "🇨🇳", country: "China"),
        Profile(handle: "marta", flag: "🇵🇱", country: "Poland"),
        Profile(handle: "ben_reads", flag: "🇺🇸", country: "USA"),
        Profile(handle: "sena", flag: "🇹🇷", country: "Türkiye"),
        Profile(handle: "olivia", flag: "🇨🇦", country: "Canada"),
        Profile(handle: "rafa", flag: "🇪🇸", country: "Spain"),
        Profile(handle: "anya", flag: "🇺🇦", country: "Ukraine"),
        Profile(handle: "milo", flag: "🇧🇪", country: "Belgium"),
        Profile(handle: "sol", flag: "🇦🇷", country: "Argentina"),
        Profile(handle: "haru", flag: "🇯🇵", country: "Japan"),
        Profile(handle: "eva", flag: "🇸🇰", country: "Slovakia"),
        Profile(handle: "arjun", flag: "🇮🇳", country: "India"),
        Profile(handle: "lily_focus", flag: "🇬🇧", country: "UK"),
        Profile(handle: "cem", flag: "🇹🇷", country: "Türkiye"),
        Profile(handle: "romy", flag: "🇳🇱", country: "Netherlands"),
        Profile(handle: "nael", flag: "🇫🇷", country: "France"),
        Profile(handle: "june", flag: "🇰🇷", country: "Korea"),
        Profile(handle: "paula", flag: "🇩🇪", country: "Germany"),
        Profile(handle: "kofi", flag: "🇬🇭", country: "Ghana"),
        Profile(handle: "alba", flag: "🇪🇸", country: "Spain"),
        Profile(handle: "tom_studies", flag: "🇬🇧", country: "UK"),
        Profile(handle: "linnea", flag: "🇸🇪", country: "Sweden"),
        Profile(handle: "youssef", flag: "🇹🇳", country: "Tunisia"),
        Profile(handle: "carmen", flag: "🇪🇸", country: "Spain"),
        Profile(handle: "dean", flag: "🇺🇸", country: "USA"),
        Profile(handle: "asel", flag: "🇰🇿", country: "Kazakhstan"),
        Profile(handle: "bea", flag: "🇵🇹", country: "Portugal"),
        Profile(handle: "kian", flag: "🇮🇷", country: "Iran"),
        Profile(handle: "sofie", flag: "🇩🇰", country: "Denmark"),
        Profile(handle: "marco", flag: "🇮🇹", country: "Italy"),
        Profile(handle: "nadia", flag: "🇷🇴", country: "Romania"),
        Profile(handle: "liam", flag: "🇮🇪", country: "Ireland"),
        Profile(handle: "yara", flag: "🇱🇧", country: "Lebanon"),
        Profile(handle: "felix", flag: "🇩🇪", country: "Germany"),
        Profile(handle: "ivy", flag: "🇺🇸", country: "USA"),
        Profile(handle: "tariq", flag: "🇯🇴", country: "Jordan"),
        Profile(handle: "elsa", flag: "🇫🇮", country: "Finland"),
        Profile(handle: "gio", flag: "🇮🇹", country: "Italy"),
        Profile(handle: "mina", flag: "🇰🇷", country: "Korea"),
        Profile(handle: "adam_focus", flag: "🇵🇱", country: "Poland"),
        Profile(handle: "rosa", flag: "🇲🇽", country: "Mexico"),
    ]
}
