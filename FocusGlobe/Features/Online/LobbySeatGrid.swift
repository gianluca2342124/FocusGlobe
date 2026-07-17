import SwiftUI

/// The shared participant-seat grid — one source of truth for how a private
/// flight's lobby looks, used both in the invite sheet's live preview and the
/// full lobby. Every seat (occupied or empty) is exactly the same size, the
/// host is first, and the number of seats is the server-defined capacity.
struct LobbySeatGrid: View {
    let participants: [RoomParticipant]
    let ownerID: String
    let myID: String?
    /// Server-defined capacity (`focus_rooms.max_members`); falls back to the
    /// client cap only when unknown.
    let capacity: Int
    /// Tapping an empty seat mints a fresh single-use invitation for it.
    var onInviteSeat: () -> Void = {}
    /// A compact preview (smaller balloons) vs. the full lobby.
    var compact: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Host first, then the rest by join time, deduplicated by UUID.
    private var ordered: [RoomParticipant] {
        var seen = Set<String>()
        let deduped = participants.filter { seen.insert($0.publicID).inserted }
        return deduped.sorted { a, b in
            if a.publicID == ownerID { return true }
            if b.publicID == ownerID { return false }
            return a.joinedAt < b.joinedAt
        }
    }

    /// Progressive, never a wall of empty seats: whoever's here plus a couple of
    /// open invites, always a small huddle, never beyond the server capacity.
    /// (1 pilot → 4 seats · 2 → 4 · 3 → 5 …, capped at capacity.)
    private var seatCount: Int {
        let cap = min(max(capacity, 2), FocusRoom.participantLimit)
        return min(cap, max(ordered.count + 2, 4))
    }
    private var balloonH: CGFloat { compact ? 40 : 54 }
    private var minCell: CGFloat { compact ? 74 : 88 }

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minCell), spacing: AppSpacing.sm)],
                  spacing: AppSpacing.sm) {
            ForEach(ordered) { p in occupiedSeat(p) }
            ForEach(0..<max(0, seatCount - ordered.count), id: \.self) { _ in emptySeat }
        }
    }

    private func occupiedSeat(_ p: RoomParticipant) -> some View {
        let isHost = p.publicID == ownerID
        let ready = p.status == .ready || p.status == .flying
        return VStack(spacing: 5) {
            ZStack(alignment: .topTrailing) {
                BalloonView(height: balloonH, showBurner: false, showGlow: ready,
                            skin: BalloonSkin.skin(id: p.balloonSkinID))
                    .frame(maxWidth: .infinity)
                if isHost {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(AppColors.gold)
                        .padding(3)
                        .background(Circle().fill(.black.opacity(0.35)))
                        .offset(x: 2, y: -2)
                }
            }
            Text(p.displayName.isEmpty ? "Sky Pilot" : p.displayName)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1).minimumScaleFactor(0.8)
            Text(ready ? "Ready" : "Not ready")
                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(ready ? Color(hex: 0x4ADE80) : .white.opacity(0.5))
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .glassBackground(cornerRadius: 16, tintOpacity: 0.24, shadowRadius: 6, shadowY: 3)
        .transition(reduceMotion ? .opacity
                    : .scale(scale: 0.85).combined(with: .opacity))
    }

    private var emptySeat: some View {
        Button {
            onInviteSeat()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: compact ? 16 : 20, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(height: balloonH)
                Text("Invite")
                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                Text(" ").font(.system(size: 10.5))   // height parity with occupied
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.4, dash: [5, 4])))
        }
        .buttonStyle(SoftPressStyle())
    }
}
