import MusicKit
import MediaPlayer
import Combine

@MainActor
class MusicService: ObservableObject {
    @Published var isAuthorized = false
    @Published var currentSong: Song?
    @Published var isPlaying = false
    private let player = ApplicationMusicPlayer.shared
    
    init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        Task {
            let status = await MusicAuthorization.request()
            self.isAuthorized = status == .authorized
        }
    }
    
    func play(song: Song) async throws {
        player.queue = [song]
        try await player.play()
        self.currentSong = song
        self.isPlaying = true
    }
    
    func pause() {
        player.pause()
        self.isPlaying = false
    }
    
    func resume() async throws {
        try await player.play()
        self.isPlaying = true
    }
    
    func stop() {
        player.stop()
        self.isPlaying = false
    }
    
    var playbackTime: TimeInterval {
        return player.playbackTime
    }
}
