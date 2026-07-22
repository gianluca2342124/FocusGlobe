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
    /// A Private Flight shows ONLY invited pilots — no decorative strangers.
    /// Distinct from `roomMode` (which also turns off in Clean Mode): decorative
    /// suppression must hold even in Clean Mode.
    var isPrivate: Bool = false
    /// Compact contextual actions on a real pilot (long-press / context menu).
    /// A deliberate "View profile" may still open a small sheet via onSelectReal.
    var onSelectReal: ((OnlinePilot) -> Void)? = nil
    var onAddFriend: ((OnlinePilot) -> Void)? = nil
    var onHide: ((OnlinePilot) -> Void)? = nil
    var onBlock: ((OnlinePilot) -> Void)? = nil
    var onReport: ((OnlinePilot) -> Void)? = nil

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

    /// One ambient (decorative) pilot currently visible in a slot, resolved from
    /// the `AmbientPilotPool` timeline at time `t`.
    private struct AmbientRender: Identifiable {
        let id: Int          // the slot index it occupies (stable identity/position)
        let slot: CGPoint
        let alias: String
        let remaining: Int?  // nil = Infinite
        let skin: BalloonSkin
        let phase: Double
    }

    /// Deterministic seed for one ambient slot in a Sky.
    private static func slotSeed(skyID: String, slot: Int) -> UInt64 {
        var h: UInt64 = 0xA13C
        for u in (skyID + "#\(slot)").unicodeScalars { h = (h &* 31) &+ UInt64(u.value) }
        return h
    }

    /// The pilot occupying a slot at time `t`, or nil during the calm gap after a
    /// finite pilot retires. Pure + deterministic, so identity and remaining time
    /// are stable across polls and only advance with `t`. A finite pilot occupies
    /// its slot for its initial remaining, then a short calm gap, then the next
    /// pool member takes the slot; an Infinite pilot holds the slot for the
    /// session (∞ never expires).
    private static func ambientAt(slotSeed: UInt64, t: Double) -> (index: Int, remaining: Int?)? {
        var rng = SeededRNG(seed: slotSeed)
        var cursor = 0.0
        let poolCount = AmbientPilotPool.all.count
        for _ in 0..<256 {                          // safety bound (never reached in practice)
            let idx = Int(rng.unit() * Double(poolCount)) % poolCount
            let entry = AmbientPilotPool.all[idx]
            guard let secs = entry.seconds else { return (idx, nil) }   // Infinite: holds forever
            let dur = Double(secs)
            if t < cursor + dur {
                return (idx, max(0, Int((cursor + dur - t).rounded())))
            }
            cursor += dur
            let gap = 9.0 + rng.unit() * 14.0       // a calm delay before the next pilot appears
            if t < cursor + gap { return nil }
            cursor += gap
        }
        return nil
    }

    /// The ambient pilots visible right now — at most one per free slot, deduped
    /// by identity, ~8–14 total (never all 100 at once).
    private func ambientRenders(t: Double, slotIndices: [Int]) -> [AmbientRender] {
        var usedIdentities = Set<Int>()
        var out: [AmbientRender] = []
        for si in slotIndices {
            let seed = Self.slotSeed(skyID: skyID, slot: si)
            guard let member = Self.ambientAt(slotSeed: seed, t: t) else { continue }
            guard !usedIdentities.contains(member.index) else { continue }   // no duplicate identities
            usedIdentities.insert(member.index)
            out.append(AmbientRender(id: si, slot: Self.skySlots[si],
                                     alias: AmbientPilotPool.all[member.index].alias,
                                     remaining: member.remaining,
                                     skin: Self.skinBag[member.index % Self.skinBag.count],
                                     phase: Double((seed >> 6) % 628) / 100.0))
        }
        return out
    }

    // MARK: - Sky-wide slot placement (collision-free by construction)

    /// Hand-placed, deliberately ASYMMETRIC anchor points spread across the whole
    /// sky — above, below, left and right of the centred user, never a ring. Every
    /// pair sits ≥ ~77 pt apart on the smallest supported iPhone (verified against
    /// 375×667 with the shared balloon size + bob/sway amplitude), so same-size
    /// balloons can never touch or overlap. All slots stay clear of the safe
    /// zones: the top status/timer area, the user balloon's centre, and the
    /// bottom flight/Cabin controls.
    /// Reserved UI rectangles this layout must respect (normalised): the top
    /// give-up / controls buttons and FocusGlobe watermark (y < ~0.09), the
    /// user's centred balloon (a ≥88 pt clearance around 0.5 / 0.5), and the
    /// bottom hero-timer + horizon band (y > ~0.72). Balanced 7 above / 5 below
    /// / 2 mid-side — organic, never a ring, never symmetric. Verified ≥70 pt
    /// between every pair on the smallest supported iPhone.
    static let skySlots: [CGPoint] = [
        CGPoint(x: 0.20, y: 0.15), CGPoint(x: 0.50, y: 0.12), CGPoint(x: 0.80, y: 0.15),
        CGPoint(x: 0.28, y: 0.26), CGPoint(x: 0.72, y: 0.27),
        CGPoint(x: 0.10, y: 0.38), CGPoint(x: 0.90, y: 0.39),
        CGPoint(x: 0.13, y: 0.52), CGPoint(x: 0.87, y: 0.54),
        CGPoint(x: 0.24, y: 0.62), CGPoint(x: 0.76, y: 0.63),
        CGPoint(x: 0.40, y: 0.68), CGPoint(x: 0.60, y: 0.69), CGPoint(x: 0.90, y: 0.70),
    ]

    /// Deterministic slot assignment: REAL pilots (sorted by stable id) claim
    /// slots first, each scanning forward from its seed-preferred slot. Returns
    /// the real→slot map AND the ordered list of slot indices left free for
    /// ambient fill (capped so real + ambient never exceeds the capacity). The
    /// same participant set therefore always produces the SAME layout (poll
    /// refreshes never shuffle anyone); only a genuine join/leave shifts anyone.
    private func assignRealSlots(real: [OnlinePilot], capacity: Int)
        -> (real: [String: CGPoint], freeAmbient: [Int]) {
        var taken = Set<Int>()
        func claim(from preferred: Int) -> Int {
            var i = preferred % Self.skySlots.count
            while taken.contains(i) { i = (i + 1) % Self.skySlots.count }
            taken.insert(i)
            return i
        }
        var realSlots: [String: CGPoint] = [:]
        for pilot in real.sorted(by: { $0.id < $1.id }) {
            let preferred = Int(stablePilotSeed(for: pilot) % UInt64(Self.skySlots.count))
            realSlots[pilot.id] = Self.skySlots[claim(from: preferred)]
        }
        let ambientBudget = max(0, capacity - real.count)
        var free: [Int] = []
        for i in 0..<Self.skySlots.count where !taken.contains(i) {
            free.append(i)
            if free.count >= ambientBudget { break }
        }
        return (realSlots, free)
    }

    /// The gentle per-pilot idle motion around a slot — small enough that the
    /// verified slot spacing can never be closed by two balloons drifting
    /// toward each other.
    private static func drift(phase: Double, t: Double) -> (CGFloat, CGFloat) {
        (CGFloat(Foundation.sin(t * 0.14 + phase * 1.3)) * 5,
         CGFloat(Foundation.sin(t * 0.22 + phase)) * 6)
    }

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            // Visual capacity: real pilots first, then ambient fill. A Private
            // Flight renders invited pilots ONLY — never a fabricated stranger;
            // Solo never mounts this layer at all. Capacity never exceeds the
            // collision-free slot count (≈8–14 balloons, never all 100 at once).
            let capacity = min(Self.skySlots.count, min(H, W) > 700 ? 14 : Self.count)
            let real = Array(realPilots.prefix(capacity))
            let assign = assignRealSlots(real: real, capacity: capacity)
            let ambientSlots = isPrivate ? [] : assign.freeAmbient
            TimelineView(.animation(minimumInterval: animated ? 1.0 / 20.0 : 5.0)) { _ in
                // Static frame (Reduce Motion) freezes the timeline at a settled
                // moment, so labels/positions are stable and legible.
                let t = animated ? max(0, elapsed()) : 24
                ZStack {
                    ForEach(Array(real.enumerated()), id: \.element.id) { _, pilot in
                        realPilotView(pilot, slot: assign.real[pilot.id] ?? Self.skySlots[0],
                                      W: W, H: H, t: t)
                    }
                    ForEach(ambientRenders(t: t, slotIndices: ambientSlots)) { a in
                        ambientPilotView(a, W: W, H: H, t: t)
                    }
                }
            }
        }
    }

    /// A single ambient (decorative) pilot: the shared balloon size + gentle
    /// bob/sway, and a PERSISTENT alias + remaining-time label — exactly like a
    /// real pilot — but purely decorative: no tap, no social actions, never
    /// presented as a real account.
    @ViewBuilder
    private func ambientPilotView(_ a: AmbientRender, W: CGFloat, H: CGFloat, t: Double) -> some View {
        let (sway, bob) = Self.drift(phase: a.phase, t: t)
        let size = Self.balloonSize(H)
        VStack(spacing: 3) {
            // Labels track the SAME switch as real pilots (`roomMode` = social
            // labels on), so Clean Mode hides every label uniformly.
            if roomMode {
                ambientBubble(alias: a.alias, remaining: a.remaining)
            }
            BalloonView(height: size, showBurner: false, showGlow: false, skin: a.skin)
        }
        .position(x: a.slot.x * W + sway, y: a.slot.y * H + bob)
        .allowsHitTesting(false)
    }

    /// The persistent ambient label: alias (full Unicode) + a decrementing
    /// MM:SS remaining, or ∞ for an Infinite pilot. Short names are never
    /// truncated; only exceptionally wide names truncate gracefully.
    private func ambientBubble(alias: String, remaining: Int?) -> some View {
        VStack(spacing: 1) {
            Text(alias)
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: 118)
            Text(remaining == nil ? "∞" : Self.clock(remaining!))
                .font(.system(size: 10.5, weight: .semibold, design: .default))
                .foregroundStyle(.white.opacity(0.72))
                .monospacedDigit()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().fill(Color.black.opacity(0.25)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        .fixedSize()
    }

    /// MM:SS from seconds (used by ambient labels).
    static func clock(_ s: Int) -> String {
        let v = max(0, s)
        return String(format: "%d:%02d", v / 60, v % 60)
    }

    /// The ONE balloon size token every pilot (and the hero) shares.
    static func balloonSize(_ H: CGFloat) -> CGFloat { max(38, min(52, H * 0.07)) }

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
    /// else; slot assigned from `stablePilotSeed` so it is stable for the
    /// whole session and identical in Cabin View.
    private func realPilotView(_ pilot: OnlinePilot, slot: CGPoint, W: CGFloat, H: CGFloat, t: Double) -> some View {
        var rng = SeededRNG(seed: stablePilotSeed(for: pilot))
        let phase = rng.unit() * 6.28
        let (sway, bob) = Self.drift(phase: phase, t: t)
        // Identical size, full opacity and NO outer glow — exactly like every
        // other balloon; a real pilot is never faded or shrunk; only their
        // POSITION differs. Their identity bubble stays up in a Private Flight;
        // in the Global sky it reveals on tap.
        let size = Self.balloonSize(H)
        // Persistent identity: every REAL pilot carries a compact alias +
        // live-countdown bubble for the whole online flight — never tap-to-
        // reveal. (`roomMode` = "social labels on"; decorative pilots get none.)
        let showBubble = roomMode || selectedRealID == pilot.id
        return ZStack(alignment: .bottom) {
            if showBubble {
                realBubble(pilot)
                    .offset(y: -size - 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
            BalloonView(height: size, showBurner: false, showGlow: false,
                        skin: BalloonSkin.skin(id: pilot.balloonSkinID))
        }
        .position(x: slot.x * W + sway, y: slot.y * H + bob)
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
        // Alias + LIVE second-exact countdown to the pilot's server-canonical
        // end ("42:18", "∞" for Infinite). Shown ONLY when the pilot has a real
        // live session — never a fabricated pill. Ticks once per second.
        VStack(spacing: 2) {
            Text("\(pilot.displayName)\(pilot.countryCode.map { " " + flagEmoji($0) } ?? "")")
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundStyle(.white)
            if pilot.hasLiveSession {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(pilot.liveCountdown(at: ctx.date))
                        .font(.system(size: 10.5, weight: .semibold, design: .default))
                        .foregroundStyle(.white.opacity(0.72))
                        .monospacedDigit()
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(.ultraThinMaterial))
        .overlay(Capsule().fill(Color.black.opacity(0.25)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
        .fixedSize()
    }

}

/// The EXACT ambient pilot pool (Part 9A): 100 aliases with an initial remaining
/// time (∞ = Infinite). Purely decorative seed data — NEVER presented as a
/// verified account. Aliases are full Unicode (emoji / Japanese / Korean /
/// Chinese / Arabic / Cyrillic / accented Latin / symbols) and rendered as-is.
enum AmbientPilotPool {
    struct Entry { let alias: String; let seconds: Int? }   // seconds == nil → Infinite

    /// Build an entry, parsing "MM:SS" → seconds, "∞" → Infinite.
    private static func e(_ alias: String, _ time: String) -> Entry {
        if time == "∞" { return Entry(alias: alias, seconds: nil) }
        let parts = time.split(separator: ":")
        let secs = parts.count == 2 ? (Int(parts[0]) ?? 0) * 60 + (Int(parts[1]) ?? 0) : 0
        return Entry(alias: alias, seconds: secs)
    }

    static let all: [Entry] = [
        e("NovaFocus", "24:18"), e("sofia.estudia", "42:07"), e("LiamWorks", "18:44"),
        e("hikari_光", "∞"), e("DiegoZen", "33:12"), e("maya.exe", "12:09"),
        e("ルナ", "27:50"), e("MinJun민준", "45:03"), e("Noor.Focus", "∞"),
        e("alex_404", "08:36"), e("CamilaFlow", "51:21"), e("EthanStudy", "19:17"),
        e("星野Hoshi", "36:40"), e("Valen.mp3", "14:55"), e("yuki_yuki", "∞"),
        e("JoãoFocus", "22:11"), e("AishaReads", "39:48"), e("N1ghtOwl", "01:59"),
        e("ClaraPomodoro", "47:05"), e("zzzStudyzzz", "16:34"), e("🌙milo", "∞"),
        e("Elena.Works", "29:42"), e("KaiFocus", "11:08"), e("lucasito_07", "54:16"),
        e("Sora空", "31:33"), e("NinaNoNoise", "07:45"), e("OmarDeepWork", "∞"),
        e("maría_🪐", "26:20"), e("TheoWrites", "44:02"), e("K!M", "13:39"),
        e("ひなた", "35:11"), e("FocusFox", "21:56"), e("EmmaOnTask", "49:30"),
        e("xXStudyCatXx", "09:27"), e("Pablo_90", "28:04"), e("Wei伟", "∞"),
        e("AnaCalma", "17:50"), e("r0bin", "41:13"), e("MeiMei", "23:37"),
        e("Sam.exe", "05:18"), e("IkerFocus", "52:49"), e("✦Luna✦", "∞"),
        e("HugoWorks", "30:25"), e("Aya_Study", "15:44"), e("MateoFlow", "38:02"),
        e("仕事中", "20:19"), e("ChloeQuiet", "46:33"), e("BcnDreamer", "10:52"),
        e("SeoulFocus", "∞"), e("Theo_∞", "∞"), e("LunaRossa", "34:21"),
        e("NereaStudy", "18:05"), e("Haru春", "43:17"), e("MaxNoScroll", "06:48"),
        e("JoséDeep", "25:59"), e("IvyFocus", "50:40"), e("ξFocusξ", "12:33"),
        e("MiaReads", "37:24"), e("DaniZen", "∞"), e("АняFocus", "22:46"),
        e("rafa.pm", "14:12"), e("Kaito海", "48:58"), e("sara<3", "09:41"),
        e("AdamInFlow", "32:15"), e("GemmaWorks", "27:03"), e("𝙉𝙤𝙫𝙖", "∞"),
        e("TomFocus", "16:28"), e("ليان", "40:06"), e("NikoStudy", "21:17"),
        e("MaeveQuiet", "53:11"), e("BlueBalloon", "08:59"), e("Carlos.M", "29:30"),
        e("さくらFocus", "∞"), e("JessOnTrack", "11:46"), e("LeoNoPause", "45:22"),
        e("Zeynep", "19:03"), e("FOCUS_99", "36:07"), e("Inés🌿", "24:49"),
        e("Momo桃", "13:14"), e("RayanReads", "∞"), e("PixelPilot", "31:45"),
        e("AlmaCalma", "17:09"), e("Joon준", "42:38"), e("lost_in_notes", "05:56"),
        e("FedeFocus", "49:12"), e("✨Ari✨", "∞"), e("NeilWorks", "20:42"),
        e("Sara_Sun", "33:57"), e("Taro太郎", "15:20"), e("M∆X", "28:31"),
        e("olivia.study", "44:45"), e("Nox", "07:13"), e("Yasmine", "∞"),
        e("PolFocus", "23:18"), e("Kira_きら", "51:07"), e("BenjiFlow", "10:04"),
        e("∞Focus∞", "∞"), e("LuciaZen", "35:26"), e("Aiden.pm", "18:52"),
        e("m00nchild", "47:39"),
    ]
}
