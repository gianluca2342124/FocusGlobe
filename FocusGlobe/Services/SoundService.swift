import AVFoundation

/// Plays a looping ambient sound during a journey.
///
/// The app ships without bundled audio for now, and that's fine: if a sound
/// file is missing, every method is a safe no-op and the app never crashes.
///
/// TODO: Add looping ambient assets to the app bundle and reference them by
/// `Route.ambientSoundName`. Planned beds:
///   • wind_soft   — soft high-altitude wind loop
///   • cabin_soft  — gentle cabin / airship ambience
///   • night_calm  — calm night-sky ambience
///   • rain_soft   — soft rain against the envelope
///   • ocean_calm  — distant calm ocean
///   • aurora_calm — shimmering aurora pad
final class SoundService {
    var isEnabled: Bool = true

    private var player: AVAudioPlayer?
    private var currentName: String?

    /// Starts (or restarts) an ambient loop. No-op if disabled or asset missing.
    func playAmbient(named name: String) {
        guard isEnabled else { return }
        guard name != currentName || player == nil else {
            resume(); return
        }
        stop()
        currentName = name

        // Try a few common extensions; absence is expected in the MVP.
        let candidates = ["m4a", "mp3", "caf", "wav"]
        guard let url = candidates.lazy
            .compactMap({ Bundle.main.url(forResource: name, withExtension: $0) })
            .first else {
            #if DEBUG
            print("🔇 [sound] No bundled asset for \"\(name)\" — skipping (expected in MVP).")
            #endif
            return
        }

        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(contentsOf: url)
            p.numberOfLoops = -1
            p.volume = 0
            p.prepareToPlay()
            p.play()
            p.setVolume(0.6, fadeDuration: 1.5) // gentle fade-in
            player = p
        } catch {
            #if DEBUG
            print("🔇 [sound] Failed to start \"\(name)\": \(error.localizedDescription)")
            #endif
        }
    }

    func pause() { player?.pause() }

    func resume() {
        guard isEnabled else { return }
        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
        currentName = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Reflects a change to the user's Sound setting mid-session.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled { player?.pause() } else { player?.play() }
    }
}
