import MusicKit
import MediaPlayer
import Combine

@MainActor
class AppleMusicService: MusicProvider {
    @Published var isAuthorized = false
    @Published var currentSong: BongoSong?
    @Published var isPlaying = false
    
    var type: MusicProviderType { .appleMusic }
    
    private let player = ApplicationMusicPlayer.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkAuthorization()
        
        // Sync playback state
        player.state.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.isPlaying = self?.player.state.playbackStatus == .playing
            }
        }.store(in: &cancellables)
    }
    
    func checkAuthorization() {
        Task {
            let status = await MusicAuthorization.request()
            self.isAuthorized = status == .authorized
        }
    }
    
    func authorize() async {
        let status = await MusicAuthorization.request()
        self.isAuthorized = status == .authorized
    }
    
    func search(query: String) async -> [BongoSong] {
        do {
            let request = MusicCatalogSearchRequest(term: query, types: [Song.self])
            // If empty query, maybe logic to load recent? API requires term usually.
            // For picking, we usually browse. Let's use search for now.
            // Fallback: if query is empty, Fetch top charts or recent (simplified)
            if query.isEmpty {
                return await loadLibrarySongs()
            }
            
            let response = try await request.response()
            return response.songs.map { song in
                BongoSong(
                    id: song.id.rawValue,
                    title: song.title,
                    artist: song.artistName,
                    artworkURL: song.artwork?.url(width: 300, height: 300),
                    duration: song.duration ?? 0,
                    originalObject: song
                )
            }
        } catch {
            print("Apple Music Search Error: \(error)")
            return []
        }
    }
    
    // Helper to load library if search is not used/empty
    private func loadLibrarySongs() async -> [BongoSong] {
        do {
            let request = MusicLibraryRequest<Song>()
            let response = try await request.response()
            return response.items.map { song in
                BongoSong(
                    id: song.id.rawValue,
                    title: song.title,
                    artist: song.artistName,
                    artworkURL: song.artwork?.url(width: 300, height: 300),
                    duration: song.duration ?? 0,
                    originalObject: song
                )
            }
        } catch {
            return []
        }
    }
    
    func play(song: BongoSong) async throws {
        guard let musicKitSong = song.originalObject as? Song else { return }
        player.queue = [musicKitSong]
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
