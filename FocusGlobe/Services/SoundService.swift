import AVFoundation
import Foundation

/// Plays a looping ambience during an active journey.
///
/// Behaviour:
///  • Uses the `.playback` audio-session category so audio keeps playing while
///    the app is backgrounded **during a journey** (this requires the "Audio"
///    Background Mode capability — see AUDIO_SETUP.md; without it iOS suspends
///    the app in the background and audio simply pauses, which is still safe).
///  • Loops the selected `JourneyAudioOption`'s bundled file (.mp3/.m4a/.wav/.caf
///    searched in that order). If the file is missing it falls back to a
///    **distinct procedural loop per option** (wind / rain / ocean / focus pad /
///    alpha pulse / relaxing pad / jazz texture) generated with AVAudioEngine —
///    so each option sounds different even before any audio files are added, and
///    it never crashes.
///  • Respects the master Sound setting (`isEnabled`). When off, nothing plays.
///  • Handles interruptions (calls / Siri) and route changes (headphones
///    removed) gracefully, resuming only when the system says it's appropriate.
///  • Never requests microphone access — this is playback only.
final class SoundService {
    var isEnabled: Bool = true

    private var player: AVAudioPlayer?
    private var ambience: ProceduralAmbience?
    private var isJourneyActive = false
    private var pausedByInterruption = false
    private var muted = false
    /// The option currently playing, so a live switch can no-op if unchanged.
    private var currentOptionID: String?
    private let targetVolume: Float = 0.6

    /// Whether the current journey audio is muted (volume 0 but still "playing",
    /// so pause/resume are unaffected).
    var isMuted: Bool { muted }

    private var observers: [NSObjectProtocol] = []

    init() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: .main) { [weak self] note in
            self?.handleInterruption(note)
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification,
                                            object: nil, queue: .main) { [weak self] note in
            self?.handleRouteChange(note)
        })
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    // MARK: - Journey playback

    /// Starts (or restarts) the journey ambience loop. No-op if Sound is off.
    func startJourney(option: JourneyAudioOption) {
        guard isEnabled else { return }
        stop()
        isJourneyActive = true
        muted = false
        currentOptionID = option.id
        configureSession()

        if let url = bundledURL(for: option.assetName),
           let p = try? AVAudioPlayer(contentsOf: url) {
            p.numberOfLoops = -1            // loop continuously
            p.volume = 0
            p.prepareToPlay()
            p.play()
            p.setVolume(targetVolume, fadeDuration: 1.5)  // gentle fade-in
            player = p
        } else {
            // No bundled file yet → a distinct procedural texture per option, so
            // premium options never just play Wind (see AUDIO_SETUP.md).
            #if DEBUG
            print("🔈 [audio] No bundled file for \"\(option.assetName)\" — procedural \(option.id) fallback.")
            #endif
            let amb = ProceduralAmbience()
            amb.start(texture: Self.texture(for: option), volume: targetVolume)
            ambience = amb
        }
    }

    /// Switch the ambience to a new option **live**, while a journey is playing
    /// (e.g. the user changes the selection). No-op if no journey is active or the
    /// option is unchanged; preserves the current mute state.
    func switchOption(_ option: JourneyAudioOption) {
        guard isEnabled, isJourneyActive, option.id != currentOptionID else { return }
        let wasMuted = muted
        startJourney(option: option)
        if wasMuted { setMuted(true) }
    }

    /// Pause the ambience (journey paused, interruption, headphones removed).
    func pause() {
        player?.pause()
        ambience?.pause()
    }

    /// Resume the ambience (journey resumed) — only while a journey is active.
    func resume() {
        guard isEnabled, isJourneyActive else { return }
        player?.play()
        ambience?.resume()
    }

    /// Stop and tear down audio (journey ended, cancelled or landed).
    func stop() {
        isJourneyActive = false
        pausedByInterruption = false
        currentOptionID = nil
        player?.stop()
        player = nil
        ambience?.stop()
        ambience = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Reflects a change to the user's master Sound setting mid-session.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled { resume() } else { pause() }
    }

    /// Mute/unmute the current journey audio without tearing it down (volume only),
    /// so pause/resume and the loop are unaffected.
    func setMuted(_ value: Bool) {
        muted = value
        let v: Float = value ? 0 : targetVolume
        player?.setVolume(v, fadeDuration: 0.2)
        ambience?.setVolume(v)
    }

    // MARK: - Option → procedural texture

    private static func texture(for option: JourneyAudioOption) -> ProceduralAmbience.Texture {
        switch option.id {
        case "rain":        return .rain
        case "ocean":       return .ocean
        case "focus-music": return .focus
        case "alpha-waves": return .alpha
        case "relaxing":    return .relaxing
        case "jazz":        return .jazz
        default:            return .wind   // "wind" and any unknown id
        }
    }

    // MARK: - Session

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Playback so journey audio can continue in the background (with the
            // Audio background capability enabled). Playback only — no recording.
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("🔈 [audio] Session config failed: \(error.localizedDescription)")
            #endif
        }
    }

    private func bundledURL(for name: String) -> URL? {
        ["mp3", "m4a", "wav", "caf"].lazy
            .compactMap { Bundle.main.url(forResource: name, withExtension: $0) }
            .first
    }

    // MARK: - Interruptions & route changes

    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
        switch type {
        case .began:
            // A call/Siri took the session — pause and remember to resume later.
            if player?.isPlaying == true || ambience?.isRunning == true {
                pausedByInterruption = true
                pause()
            }
        case .ended:
            guard pausedByInterruption else { return }
            pausedByInterruption = false
            let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt)
                .map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false
            if shouldResume {
                try? AVAudioSession.sharedInstance().setActive(true)
                resume()
            }
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ note: Notification) {
        guard let info = note.userInfo,
              let raw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }
        // Headphones unplugged → pause (standard media behaviour); don't force a
        // resume, to avoid suddenly blasting audio from the speaker.
        if reason == .oldDeviceUnavailable { pause() }
    }
}

// MARK: - Procedural ambience fallback

/// A lightweight procedural ambience engine — the safe fallback when no audio
/// file is bundled yet. It synthesises a **distinct** calm texture per option
/// using AVAudioEngine, all allocation-free in the render block (cheap; won't
/// drop frames during the map animation). Everything is heavily smoothed / low
/// level so it stays premium and non-distracting, never harsh.
private final class ProceduralAmbience {
    enum Texture { case wind, rain, ocean, focus, alpha, relaxing, jazz }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private(set) var isRunning = false

    func start(texture: Texture, volume: Float) {
        let mixer = engine.mainMixerNode               // touch first to build the graph
        let outRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = outRate > 0 ? outRate : 44_100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        let srf = Float(sampleRate)
        let twoPi = Float(2.0 * Double.pi)
        func inc(_ f: Float) -> Float { twoPi * f / srf }

        // Precomputed phase increments (allocation-free render block).
        let lfoInc = inc(0.05)        // very slow swell
        let oceanInc = inc(0.10)      // ~10 s wave period
        let alphaInc = inc(9.0)       // alpha-range pulse
        let swingInc = inc(1.1)       // gentle jazz swing
        let fFocus1 = inc(96),  fFocus2 = inc(144)
        let fAlpha1 = inc(110)
        let fRelax1 = inc(98),  fRelax2 = inc(123.5), fRelax3 = inc(147)
        let fJazz1  = inc(73)

        // Captured render state (mutated only on the audio thread).
        var lp1: Float = 0, lp2: Float = 0
        var lfo: Float = 0, ocean: Float = 0, alpha: Float = 0, swing: Float = 0
        var o1: Float = 0, o2: Float = 0, o3: Float = 0
        var seed: UInt32 = 0x9E3779B9

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                // Fast xorshift32 white noise in [-1, 1].
                seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
                let white = (Float(seed) / Float(UInt32.max)) * 2 - 1

                lfo += lfoInc; if lfo > twoPi { lfo -= twoPi }
                let slow = sinf(lfo)

                var sample: Float = 0
                switch texture {
                case .wind:
                    // Soft balloon air: cascaded low-pass noise, slow gusting.
                    lp1 += 0.02 * (white - lp1); lp2 += 0.02 * (lp1 - lp2)
                    sample = lp2 * 13.0 * (0.6 + 0.18 * slow)
                case .rain:
                    // Soft distant rain: lighter low-pass → airy hiss, gentle.
                    lp1 += 0.30 * (white - lp1)
                    sample = lp1 * 1.6 * (0.55 + 0.08 * slow)
                case .ocean:
                    // Gentle waves: cascaded noise with a slow surging swell.
                    lp1 += 0.02 * (white - lp1); lp2 += 0.02 * (lp1 - lp2)
                    ocean += oceanInc; if ocean > twoPi { ocean -= twoPi }
                    sample = lp2 * 13.0 * (0.35 + 0.5 * (0.5 + 0.5 * sinf(ocean)))
                case .focus:
                    // Minimal tonal bed: low drone + a soft fifth, gentle tremolo.
                    o1 += fFocus1; o2 += fFocus2
                    sample = (sinf(o1) * 0.6 + sinf(o2) * 0.35) * (0.85 + 0.15 * slow) * 0.30
                case .alpha:
                    // Calm low tone, pulsing in the alpha range.
                    o1 += fAlpha1
                    alpha += alphaInc; if alpha > twoPi { alpha -= twoPi }
                    sample = sinf(o1) * (0.55 + 0.35 * sinf(alpha)) * 0.30
                case .relaxing:
                    // Warm pad: a soft detuned triad with a slow swell.
                    o1 += fRelax1; o2 += fRelax2; o3 += fRelax3
                    sample = ((sinf(o1) + 0.8 * sinf(o2) + 0.7 * sinf(o3)) / 2.5) * (0.8 + 0.2 * slow) * 0.30
                case .jazz:
                    // Subtle lounge texture: brushed noise + soft bass, swing pulse.
                    lp1 += 0.22 * (white - lp1)
                    o1 += fJazz1
                    swing += swingInc; if swing > twoPi { swing -= twoPi }
                    sample = (lp1 * 1.5 + sinf(o1) * 0.4) * (0.4 + 0.3 * abs(sinf(swing))) * 0.45
                }

                // Keep tone phases bounded; clamp for safety (no clipping).
                if o1 > twoPi { o1 -= twoPi }; if o2 > twoPi { o2 -= twoPi }; if o3 > twoPi { o3 -= twoPi }
                if sample > 0.95 { sample = 0.95 } else if sample < -0.95 { sample = -0.95 }

                for bufferIndex in 0..<abl.count {
                    if let data = abl[bufferIndex].mData {
                        data.assumingMemoryBound(to: Float.self)[frame] = sample
                    }
                }
            }
            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: mixer, format: format)
        mixer.outputVolume = volume
        do {
            try engine.start()
            sourceNode = node
            isRunning = true
        } catch {
            #if DEBUG
            print("🔈 [audio] Procedural ambience failed to start: \(error.localizedDescription)")
            #endif
        }
    }

    /// Set the output level (used for mute/unmute without stopping the engine).
    func setVolume(_ v: Float) {
        engine.mainMixerNode.outputVolume = v
    }

    func pause() {
        guard isRunning else { return }
        engine.pause()
        isRunning = false
    }

    func resume() {
        guard !isRunning, sourceNode != nil else { return }
        if (try? engine.start()) != nil { isRunning = true }
    }

    func stop() {
        if let node = sourceNode { engine.detach(node) }
        engine.stop()
        sourceNode = nil
        isRunning = false
    }
}
