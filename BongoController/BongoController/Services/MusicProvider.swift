import Foundation
import Combine

enum MusicProviderType: String, CaseIterable, Identifiable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    
    var id: String { rawValue }
}

struct BongoSong: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let artworkURL: URL?
    let duration: TimeInterval
    
    // Opaque storage for the underlying provider object (MusicKit.Song or Spotify Dictionary)
    let originalObject: Any?
    
    static func == (lhs: BongoSong, rhs: BongoSong) -> Bool {
        return lhs.id == rhs.id
    }
}

protocol MusicProvider: ObservableObject {
    var type: MusicProviderType { get }
    var isAuthorized: Bool { get }
    var currentSong: BongoSong? { get }
    var isPlaying: Bool { get }
    var playbackTime: TimeInterval { get }
    
    func checkAuthorization() async
    func authorize() async
    func search(query: String) async -> [BongoSong]
    func play(song: BongoSong) async throws
    func pause()
    func resume() async throws
    func stop()
}
