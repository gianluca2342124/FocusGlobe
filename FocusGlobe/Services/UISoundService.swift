import AudioToolbox
import Foundation

/// Subtle, premium UI **earcons** for key interaction moments.
///
/// This is the *interaction-sound* layer, deliberately kept separate from
/// `SoundService` (the looping ambient journey audio) so the two never fight:
///  • `SoundService` owns the AVAudioSession (`.playback`) for the journey loop.
///  • `UISoundService` plays one-shot earcons through AudioToolbox's system-sound
///    services, which **mix over** the ambient audio rather than ducking or
///    stopping it.
///
/// Each earcon prefers a bundled audio file (clearly named `ui_<earcon>` —
/// e.g. `ui_confirm.caf`) and falls back to a tasteful built-in iOS system sound
/// when no file is present. So the layer is premium-ready immediately and can be
/// upgraded later by simply dropping audio files into the app bundle — no code
/// change required (see UI_SOUNDS_SETUP.md).
///
/// Respects the master Sound setting via `isEnabled` (mirrors `settings.soundEnabled`).
@MainActor
final class UISoundService {
    var isEnabled = true

    /// Meaningful moments — intentionally a short, curated list (not every tap).
    enum Earcon: String, CaseIterable {
        case tap            // a key / primary CTA tap
        case transition     // moving into a new important screen
        case focusDrop      // a focus token snaps into the basket
        case confirm        // confirming the focus / a commit
        case journeyStart   // take-off, the journey begins
        case ticketTear     // tearing the boarding ticket
        case landing        // arriving / landing
        case modal          // opening an important modal (e.g. paywall)
    }

    private var resolved: [Earcon: SystemSoundID] = [:]

    /// Play an earcon. No-op when Sound is disabled.
    func play(_ earcon: Earcon) {
        guard isEnabled else { return }
        AudioServicesPlaySystemSound(soundID(for: earcon))
    }

    // MARK: - Resolution (bundled file → system fallback), cached

    private func soundID(for earcon: Earcon) -> SystemSoundID {
        if let id = resolved[earcon] { return id }
        let id = resolveSoundID(for: earcon)
        resolved[earcon] = id
        return id
    }

    private func resolveSoundID(for earcon: Earcon) -> SystemSoundID {
        let name = "ui_\(earcon.rawValue)"
        for ext in ["caf", "aif", "aiff", "wav", "m4a"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                var sid: SystemSoundID = 0
                if AudioServicesCreateSystemSoundID(url as CFURL, &sid) == noErr {
                    return sid
                }
            }
        }
        return earcon.systemFallback
    }
}

private extension UISoundService.Earcon {
    /// Built-in iOS system-sound IDs used until bundled assets are added. These
    /// are deliberately the short, soft "tock/tink" family — clean and premium,
    /// never the loud alert tones. Replaceable by adding `ui_<name>` audio files.
    var systemFallback: SystemSoundID {
        switch self {
        case .tap:          return 1104   // soft keyboard press
        case .transition:   return 1103   // "Tock"
        case .focusDrop:    return 1057   // "Tink" — settling into place
        case .confirm:      return 1057   // "Tink"
        case .journeyStart: return 1103   // "Tock"
        case .ticketTear:   return 1105   // keyboard delete (short, dry)
        case .landing:      return 1057   // "Tink"
        case .modal:        return 1104   // soft keyboard press
        }
    }
}
