import Foundation

struct SpotifyConfig {
    // USER ACTION REQUIRED: Get these from https://developer.spotify.com/dashboard
    static let clientID = "YOUR_CLIENT_ID_HERE"
    // Note: For Authorization Code Flow with PKCE (recommended for mobile), we technically don't need Client Secret if using PKCE properly, but standard Code flow needs it. 
    // However, keeping secrets in the app is not secure. 
    // We will use Implicit Grant or PKCE. PKCE is best.
    
    static let redirectURI = "bongo-controller://spotify-login-callback"
    
    // Scopes needed
    static let scopes = "user-read-playback-state user-modify-playback-state user-read-currently-playing app-remote-control streaming playlist-read-private"
}
