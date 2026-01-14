import Foundation
import Combine
import AuthenticationServices

@MainActor
class SpotifyService: NSObject, MusicProvider {
    @Published var isAuthorized = false
    @Published var currentSong: BongoSong?
    @Published var isPlaying = false
    
    var type: MusicProviderType { .spotify }
    
    private var accessToken: String?
    private var refreshToken: String?
    
    // Playback state estimation
    private var lastSyncedPlaybackTime: TimeInterval = 0
    private var lastSyncedDate: Date = Date()
    private var syncTimer: Timer?
    private var localTimer: Timer?
    
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        // Check if we have a token saved
        if let token = UserDefaults.standard.string(forKey: "spotify_access_token") {
            self.accessToken = token
            self.isAuthorized = true
            startStateSync()
        }
    }
    
    func checkAuthorization() async {
        // Already checked in init logic
    }
    
    func authorize() async {
        guard let authURL = generateAuthURL() else { return }
        
        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(url: authURL, callbackURLScheme: "bongo-controller") { callbackURL, error in
                if let error = error {
                    print("Auth error: \(error)")
                    continuation.resume()
                    return
                }
                
                guard let callbackURL = callbackURL,
                      let code = URLComponents(string: callbackURL.absoluteString)?.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume()
                    return
                }
                
                Task {
                    await self.exchangeCodeForToken(code: code)
                    continuation.resume()
                }
            }
            
            session.presentationContextProvider = self
            session.start()
        }
    }
    
    private func generateAuthURL() -> URL? {
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")
        components?.queryItems = [
            URLQueryItem(name: "client_id", value: SpotifyConfig.clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: SpotifyConfig.redirectURI),
            URLQueryItem(name: "scope", value: SpotifyConfig.scopes),
            // For PKCE we would add code_challenge, keeping it simple for MVP implied grant/code
        ]
        return components?.url
    }
    
    private func exchangeCodeForToken(code: String) async {
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = "grant_type=authorization_code&code=\(code)&redirect_uri=\(SpotifyConfig.redirectURI)&client_id=\(SpotifyConfig.clientID)" 
        // Note: If using strict authorization code flow, client_secret is needed. 
        // Since we don't have a secure backend, we should use PKCE. 
        // BUT, implementing PKCE cleanly in one file is verbose. 
        // HACK: We will assume the user puts a Client ID that works (Desktop app usually requires Secret, Mobile *can* use PKCE). 
        // If this fails, the user will need to add Client Secret to Config. 
        
        request.httpBody = body.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["access_token"] as? String {
                self.accessToken = token
                UserDefaults.standard.set(token, forKey: "spotify_access_token")
                self.isAuthorized = true
                self.startStateSync()
            }
        } catch {
            print("Token exchange error: \(error)")
        }
    }
    
    // MARK: - Playback Control
    
    private func startStateSync() {
        // Sync every 3 seconds
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.fetchCurrentState() }
        }
        
        // Local timer updates UI/Game property only? 
        // Actually `playbackTime` is computed property, so we just need `lastSyncedDate`
    }
    
    private func fetchCurrentState() async {
        guard let token = accessToken else { return }
        let url = URL(string: "https://api.spotify.com/v1/me/player")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if (response as? HTTPURLResponse)?.statusCode == 204 {
                // No content, nothing playing
                self.isPlaying = false
                return
            }
            
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let isPlaying = json["is_playing"] as? Bool ?? false
                let progressMs = json["progress_ms"] as? Int ?? 0
                
                DispatchQueue.main.async {
                    self.isPlaying = isPlaying
                    self.lastSyncedPlaybackTime = Double(progressMs) / 1000.0
                    self.lastSyncedDate = Date()
                    
                    if let item = json["item"] as? [String: Any] {
                        self.updateCurrentSong(from: item)
                    }
                }
            }
        } catch {
            print("State fetch error: \(error)")
        }
    }
    
    private func updateCurrentSong(from json: [String: Any]) {
        let id = json["id"] as? String ?? ""
        let name = json["name"] as? String ?? "Unknown"
        let artists = (json["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ") ?? "Unknown"
        let durationMs = json["duration_ms"] as? Int ?? 0
        
        var artworkURL: URL?
        if let album = json["album"] as? [String: Any],
           let images = album["images"] as? [[String: Any]],
           let firstUrl = images.first?["url"] as? String {
            artworkURL = URL(string: firstUrl)
        }
        
        self.currentSong = BongoSong(
            id: id,
            title: name,
            artist: artists,
            artworkURL: artworkURL,
            duration: Double(durationMs) / 1000.0,
            originalObject: json
        )
    }
    
    // MARK: - MusicProvider Implementation
    
    func search(query: String) async -> [BongoSong] {
        guard let token = accessToken else { return [] }
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return [] }
        
        let url = URL(string: "https://api.spotify.com/v1/search?q=\(encodedQuery)&type=track&limit=10")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let tracks = json["tracks"] as? [String: Any],
               let items = tracks["items"] as? [[String: Any]] {
                
                return items.map { item in
                    let id = item["id"] as? String ?? ""
                    let name = item["name"] as? String ?? "Unknown"
                    let artists = (item["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: ", ") ?? "Unknown"
                    let durationMs = item["duration_ms"] as? Int ?? 0
                    
                    var artworkURL: URL?
                    if let album = item["album"] as? [String: Any],
                       let images = album["images"] as? [[String: Any]],
                       let firstUrl = images.first?["url"] as? String {
                        artworkURL = URL(string: firstUrl)
                    }
                    
                    return BongoSong(
                        id: id,
                        title: name,
                        artist: artists,
                        artworkURL: artworkURL,
                        duration: Double(durationMs) / 1000.0,
                        originalObject: item
                    )
                }
            }
        } catch {
            print("Search error: \(error)")
        }
        return []
    }
    
    func play(song: BongoSong) async throws {
        guard let token = accessToken else { return }
        // To play a specific song, we use PUT /me/player/play with context_uri or uris
        // Song object should contain uri
        guard let json = song.originalObject as? [String: Any],
              let uri = json["uri"] as? String else { return }
        
        let url = URL(string: "https://api.spotify.com/v1/me/player/play")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: Any] = ["uris": [uri]]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 204 {
            DispatchQueue.main.async {
                self.isPlaying = true
                self.currentSong = song
                self.lastSyncedPlaybackTime = 0
                self.lastSyncedDate = Date()
                Task { await self.fetchCurrentState() }
            }
        } else {
            // Need active device
            print("Play failed: Active device required")
        }
    }
    
    func pause() {
        guard let token = accessToken else { return }
        let url = URL(string: "https://api.spotify.com/v1/me/player/pause")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        Task {
            _ = try? await URLSession.shared.data(for: request)
            DispatchQueue.main.async {
                self.isPlaying = false
            }
        }
    }
    
    func resume() async throws {
        guard let token = accessToken else { return }
        let url = URL(string: "https://api.spotify.com/v1/me/player/play")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (_, _) = try await URLSession.shared.data(for: request)
        DispatchQueue.main.async {
            self.isPlaying = true
            self.lastSyncedDate = Date()
        }
    }
    
    func stop() {
        pause()
    }
    
    var playbackTime: TimeInterval {
        if isPlaying {
            // Extrapolate
            let elapsed = Date().timeIntervalSince(lastSyncedDate)
            return lastSyncedPlaybackTime + elapsed
        } else {
            return lastSyncedPlaybackTime
        }
    }
}

extension SpotifyService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return ASPresentationAnchor()
    }
}
