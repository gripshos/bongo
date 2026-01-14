import Foundation
import Combine
import SwiftUI

@MainActor
class MusicService: ObservableObject {
    @Published var providerType: MusicProviderType = .appleMusic {
        didSet {
            updateProvider()
        }
    }
    
    @Published var isAuthorized = false
    @Published var currentSong: BongoSong?
    @Published var isPlaying = false
    
    private var activeProvider: any MusicProvider
    private var cancellables = Set<AnyCancellable>()
    
    private let appleMusic = AppleMusicService()
    private let spotify = SpotifyService()
    
    init() {
        // Default to Apple Music
        self.activeProvider = appleMusic
        
        setupSubscriptions()
    }
    
    private func updateProvider() {
        // Stop previous
        activeProvider.stop()
        
        switch providerType {
        case .appleMusic:
            activeProvider = appleMusic
        case .spotify:
            activeProvider = spotify
        }
        
        setupSubscriptions()
        checkAuthorization()
    }
    
    private func setupSubscriptions() {
        cancellables.removeAll()
        
        activeProvider.isAuthorizedPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.isAuthorized, on: self)
            .store(in: &cancellables)
            
        activeProvider.currentSongPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.currentSong, on: self)
            .store(in: &cancellables)
            
        activeProvider.isPlayingPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.isPlaying, on: self)
            .store(in: &cancellables)
    }
    
    func checkAuthorization() {
        Task {
            await activeProvider.checkAuthorization()
        }
    }
    
    func authorize() async {
        await activeProvider.authorize()
    }
    
    func play(song: BongoSong) async throws {
        try await activeProvider.play(song: song)
    }
    
    func pause() {
        activeProvider.pause()
    }
    
    func resume() async throws {
        try await activeProvider.resume()
    }
    
    func stop() {
        activeProvider.stop()
    }
    
    func search(query: String) async -> [BongoSong] {
        return await activeProvider.search(query: query)
    }
    
    var playbackTime: TimeInterval {
        return activeProvider.playbackTime
    }
}

// Extensions to expose Publishers from Protocol for the adapter
extension MusicProvider {
    var isAuthorizedPublisher: AnyPublisher<Bool, Never> {
        // Type erasure for the @Published property is tricky in protocol.
        // We cast to specific types since we know them, or require protocol to expose publisher.
        // Protocol requirements for @Published are messy.
        // Easiest is to type check or add publisher requirement to protocol.
        
        if let service = self as? AppleMusicService {
            return service.$isAuthorized.eraseToAnyPublisher()
        } else if let service = self as? SpotifyService {
            return service.$isAuthorized.eraseToAnyPublisher()
        }
        return Just(false).eraseToAnyPublisher()
    }
    
    var currentSongPublisher: AnyPublisher<BongoSong?, Never> {
        if let service = self as? AppleMusicService {
            return service.$currentSong.eraseToAnyPublisher()
        } else if let service = self as? SpotifyService {
            return service.$currentSong.eraseToAnyPublisher()
        }
        return Just(nil).eraseToAnyPublisher()
    }
    
    var isPlayingPublisher: AnyPublisher<Bool, Never> {
        if let service = self as? AppleMusicService {
            return service.$isPlaying.eraseToAnyPublisher()
        } else if let service = self as? SpotifyService {
            return service.$isPlaying.eraseToAnyPublisher()
        }
        return Just(false).eraseToAnyPublisher()
    }
}
