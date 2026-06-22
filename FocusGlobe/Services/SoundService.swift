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
///    **procedural soft-wind** loop generated with AVAudioEngine, so the feature
///    works before any audio files are added and never crashes.
///  • Respects the master Sound setting (`isEnabled`). When off, nothing plays.
///  • Handles interruptions (calls / Siri) and route changes (headphones
///    removed) gracefully, resuming only when the system says it's appropriate.
///  • Never requests microphone access — this is playback only.
final class SoundService {
    var isEnabled: Bool = true

    private var player: AVAudioPlayer?
    private var wind: ProceduralWind?
    private var isJourneyActive = false
    private var pausedByInterruption = false
    private let targetVolume: Float = 0.6

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
            // No bundled file yet → procedural soft wind/air (see AUDIO_SETUP.md).
            #if DEBUG
            print("🔈 [audio] No bundled file for \"\(option.assetName)\" — using procedural wind fallback.")
            #endif
            let w = ProceduralWind()
            w.start(volume: targetVolume)
            wind = w
        }
    }

    /// Pause the ambience (journey paused, interruption, headphones removed).
    func pause() {
        player?.pause()
        wind?.pause()
    }

    /// Resume the ambience (journey resumed) — only while a journey is active.
    func resume() {
        guard isEnabled, isJourneyActive else { return }
        player?.play()
        wind?.resume()
    }

    /// Stop and tear down audio (journey ended, cancelled or landed).
    func stop() {
        isJourneyActive = false
        pausedByInterruption = false
        player?.stop()
        player = nil
        wind?.stop()
        wind = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    /// Reflects a change to the user's master Sound setting mid-session.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled { resume() } else { pause() }
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
            if player?.isPlaying == true || wind?.isRunning == true {
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

// MARK: - Procedural wind fallback

/// A lightweight procedural "soft wind/air" loop using AVAudioEngine — the safe
/// fallback when no audio file is bundled yet. It is low-passed white noise with
/// a slow gusting envelope; the render block is allocation-free and cheap, so it
/// won't cause frame drops during the map animation.
private final class ProceduralWind {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private(set) var isRunning = false

    func start(volume: Float) {
        let mixer = engine.mainMixerNode               // touch first to build the graph
        let outRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        let sampleRate = outRate > 0 ? outRate : 44_100
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else { return }

        // Captured render state (mutated only on the audio thread).
        var lpState: Float = 0
        var lfoPhase: Float = 0
        let lfoInc = Float(2.0 * Double.pi * 0.08 / sampleRate)   // ~0.08 Hz gusting
        var seed: UInt32 = 0x9E3779B9
        let twoPi = Float(2.0 * Double.pi)

        let node = AVAudioSourceNode { _, _, frameCount, audioBufferList -> OSStatus in
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            for frame in 0..<Int(frameCount) {
                // Fast xorshift32 white noise in [-1, 1].
                seed ^= seed << 13; seed ^= seed >> 17; seed ^= seed << 5
                let white = (Float(seed) / Float(UInt32.max)) * 2 - 1
                // One-pole low-pass → soft, airy timbre (not a hiss).
                lpState += 0.018 * (white - lpState)
                // Slow gusting amplitude envelope.
                lfoPhase += lfoInc
                if lfoPhase > twoPi { lfoPhase -= twoPi }
                let gust = 0.55 + 0.45 * sinf(lfoPhase)
                let sample = lpState * 3.2 * gust         // lift the quiet LP output
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
            print("🔈 [audio] Procedural wind failed to start: \(error.localizedDescription)")
            #endif
        }
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
