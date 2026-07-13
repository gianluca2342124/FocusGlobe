import Foundation
import SwiftUI

/// Fellow balloons sharing the Sky during a flight — quiet, far away, **floating**
/// calmly (never falling), each holding roughly its own patch of sky with a
/// gentle bob + sway. Hidden entirely when the pilot chooses a solo flight.
///
/// HONESTY: these are local **mock** travellers until the presence backend
/// (`SkyPresenceService`) ships — deterministically seeded per Sky so a session
/// feels stable but varied. `SkyActivity.isLive` stays `false`; nothing here is
/// presented as verified real-time online users. When real presence arrives,
/// this layer swaps its data source 1:1.
struct AmbientPilotsLayer: View {
    let skyID: String
    /// Pause-aware elapsed seconds — pilots hold still while paused.
    let elapsed: () -> Double
    var animated: Bool = true

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

    /// How many fellow balloons share the Sky (kept modest so the user balloon
    /// stays dominant). Between 10 and 20 per the design brief.
    private static let count = 13

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
            list.append(Pilot(fx: 0.08 + rng.unit() * 0.84,
                              fy: 0.10 + rng.unit() * 0.66,
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
            TimelineView(.animation(minimumInterval: animated ? 1.0 / 20.0 : 5.0)) { _ in
                let t = animated ? elapsed() : 0
                ZStack {
                    ForEach(Array(pilots.enumerated()), id: \.offset) { index, pilot in
                        pilotView(pilot, index: index, W: W, H: H, t: t)
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
        let size = CGFloat(14 + p.depth * 14)
        let alpha = 0.34 + p.depth * 0.36

        ZStack(alignment: .bottom) {
            if selectedPilot == index {
                pilotBubble(p)
                    .offset(y: -size - 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            BalloonView(height: size, showBurner: false, showGlow: false, skin: p.skin)
                .opacity(alpha)
        }
        .position(x: x, y: y)
        .onTapGesture {
            appTapSelect(index)
        }
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
