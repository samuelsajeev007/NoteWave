import AVFoundation
import Foundation
import MediaPlayer
import Observation

/// Wraps AVPlayer. Supports seek, variable speed, lock-screen controls.
@Observable
final class AudioPlayerManager: NSObject {

    // MARK: - Observable State
    var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    var playbackSpeed: Float = 1.0
    var isRepeatEnabled = false
    var currentURL: URL?
    var lastError: String? = nil

    // MARK: - Private
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var itemObserver: NSObjectProtocol?

    // MARK: - Load & Play

    func loadAndPlay(url: URL, title: String = "") throws {
        stop()
        try AudioSessionManager.shared.configureForPlayback()

        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        
        // Use timeDomain algorithm so changing speed doesn't change pitch (no chipmunk effect)
        item.audioTimePitchAlgorithm = .timeDomain

        let p = AVPlayer(playerItem: item)
        // Set rate directly (automatically begins playback)
        p.rate = playbackSpeed
        
        player = p
        currentURL = url
        
        // Extract duration synchronously since it's a local file
        let dur = CMTimeGetSeconds(asset.duration)
        duration = dur.isFinite ? dur : 0
        currentTime = 0
        isPlaying = true
        lastError = nil

        startProgressTimer()
        observeCompletion(for: item)
        
        configureNowPlaying(title: title.isEmpty ? url.deletingPathExtension().lastPathComponent : title,
                            duration: duration)
    }

    func play() {
        guard let p = player else { return }
        p.rate = playbackSpeed
        isPlaying = true
        lastError = nil
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingTime()
    }

    func stop() {
        player?.pause()
        stopProgressTimer()
        if let itemObserver { NotificationCenter.default.removeObserver(itemObserver) }
        itemObserver = nil
        
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        currentURL = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = time
        updateNowPlayingTime()
    }

    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying {
            player?.rate = speed
        }
    }

    func toggleRepeat() {
        isRepeatEnabled.toggle()
        // Repeat is handled in the completion observer for AVPlayer
    }

    // MARK: - Progress Timer

    private func startProgressTimer() {
        guard let p = player else { return }
        timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.05, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            // Update playing state accurately
            self.isPlaying = p.timeControlStatus == .playing || p.timeControlStatus == .waitingToPlayAtSpecifiedRate
        }
    }

    private func stopProgressTimer() {
        if let obs = timeObserver {
            player?.removeTimeObserver(obs)
            timeObserver = nil
        }
    }
    
    private func observeCompletion(for item: AVPlayerItem) {
        if let itemObserver { NotificationCenter.default.removeObserver(itemObserver) }
        itemObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            guard let self else { return }
            if self.isRepeatEnabled {
                self.seek(to: 0)
                self.play()
            } else {
                self.isPlaying = false
                self.currentTime = self.duration
            }
        }
    }

    // MARK: - Now Playing

    private func configureNowPlaying(title: String, duration: TimeInterval) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info

        let cc = MPRemoteCommandCenter.shared()
        cc.playCommand.isEnabled = true
        cc.pauseCommand.isEnabled = true
        cc.changePlaybackPositionCommand.isEnabled = true

        cc.playCommand.addTarget { [weak self] _ in self?.play(); return .success }
        cc.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        cc.changePlaybackPositionCommand.addTarget { [weak self] event in
            if let e = event as? MPChangePlaybackPositionCommandEvent {
                self?.seek(to: e.positionTime)
                return .success
            }
            return .commandFailed
        }
    }

    private func updateNowPlayingTime() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
