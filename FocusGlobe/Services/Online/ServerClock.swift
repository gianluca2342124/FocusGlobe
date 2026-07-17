import Foundation

/// A shared, server-anchored clock. Every online countdown (host timer, guest
/// timer, invitation preview, pilot bubbles) reads its estimate of *server*
/// time from here, so two devices with different — even manually wrong — wall
/// clocks still finish a flight together.
///
/// How it works
///   Each RPC that returns `server_now` is folded in as a sample. From the
///   local send/receive timestamps we estimate the round trip and the local
///   midpoint of the request, then `offset = serverNow − midpoint`. The anchor
///   is stored against a **monotonic** reference (`ProcessInfo.systemUptime`,
///   which is immune to wall-clock changes), so between synchronizations the
///   estimate advances by real elapsed time and a manual clock change does not
///   create a countdown jump. We keep the freshest low-latency sample and
///   ignore obvious high-latency outliers.
///
/// Background note: `systemUptime` does not advance while the device sleeps, so
/// the estimate must be re-synced when the app returns to the foreground — the
/// model does this on the flight poll pipeline and on `.active`.
@MainActor
final class ServerClock {

    /// The server instant captured at the anchor, and the monotonic reading at
    /// that same instant. `estimatedServerNow` extrapolates from here.
    private var anchorServerTime: Date?
    private var anchorUptime: TimeInterval = 0
    /// Round-trip time of the anchor sample — used to prefer lower-latency ones.
    private var anchorRTT: TimeInterval = .greatestFiniteMagnitude

    private func uptime() -> TimeInterval { ProcessInfo.processInfo.systemUptime }

    /// Fold in one `server_now` sample. `requestStartedAt` is when we sent the
    /// RPC, `responseReceivedAt` when we got it back (both local wall clock,
    /// used only to measure the round trip — never as absolute truth), and
    /// `receivedUptime` the monotonic reading captured alongside the response.
    func record(serverNow: Date,
                requestStartedAt: Date,
                responseReceivedAt: Date,
                receivedUptime: TimeInterval) {
        let rtt = max(0, responseReceivedAt.timeIntervalSince(requestStartedAt))
        // The server clock at the moment we RECEIVED the response is ~serverNow
        // plus half the round trip (the response spent ~rtt/2 in flight).
        let serverAtReceipt = serverNow.addingTimeInterval(rtt / 2)

        let age = uptime() - anchorUptime
        let anchorStale = age > 30            // > one poll interval → refresh regardless
        let betterLatency = rtt <= anchorRTT * 1.5
        let lowLatency = rtt < 0.6            // a good sample is always worth taking
        guard anchorServerTime == nil || anchorStale || betterLatency || lowLatency else {
            return                            // keep the current, better anchor
        }
        anchorServerTime = serverAtReceipt
        anchorUptime = receivedUptime
        anchorRTT = rtt
    }

    /// Best estimate of the current server time. Extrapolated from the anchor
    /// along the monotonic clock, so it is unaffected by wall-clock edits.
    /// Falls back to the device clock until the first sample lands.
    var estimatedServerNow: Date {
        guard let anchorServerTime else { return Date() }
        return anchorServerTime.addingTimeInterval(uptime() - anchorUptime)
    }

    /// `true` once at least one server sample has been folded in.
    var hasSample: Bool { anchorServerTime != nil }

    /// serverNow − localNow, for legacy call sites that shift a server timestamp
    /// into local `Date()` space (pilot bubbles, the preview label). Recomputed
    /// on demand so it always reflects the freshest anchor.
    var offset: TimeInterval { estimatedServerNow.timeIntervalSince(Date()) }
}
