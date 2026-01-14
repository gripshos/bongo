import SwiftUI
import MusicKit

struct ContentView: View {
    @StateObject private var musicService = MusicService()
    @StateObject private var wsManager = WebSocketServerManager()
    
    @State private var showingGame = false
    @State private var showSongPicker = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).ignoresSafeArea()
            
            if showingGame {
                GameView(musicService: musicService, wsManager: wsManager)
            } else {
                VStack(spacing: 30) {
                    // Header
                    VStack {
                        Text("BONGO")
                            .font(.system(size: 60, weight: .black, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("CONTROLLER")
                            .font(.headline)
                            .tracking(5)
                    }
                    
                    // Provider Selection
                    Picker("Music Provider", selection: $musicService.providerType) {
                        ForEach(MusicProviderType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: musicService.providerType) {
                        // Reset selection on change
                        musicService.currentSong = nil
                    }
                    
                    if !musicService.isAuthorized {
                        Button("Authorize \(musicService.providerType.rawValue)") {
                            Task {
                                await musicService.authorize()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    
                    // Connection Status
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CONNECTION STATUS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Image(systemName: wsManager.isRunning ? "wifi" : "wifi.slash")
                                .foregroundColor(wsManager.isRunning ? .green : .red)
                            Text(wsManager.serverIP)
                                .font(.system(.body, design: .monospaced))
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(10)
                        
                        Text(wsManager.clientConnected ? "Web Display Connected" : "Waiting for Web Display...")
                            .font(.caption)
                            .foregroundColor(wsManager.clientConnected ? .green : .orange)
                    }
                    .padding()
                    
                    // Song Selection
                    Button(action: { showSongPicker = true }) {
                        HStack {
                            Image(systemName: "music.note.list")
                            Text(musicService.currentSong?.title ?? "Select Song")
                                .fontWeight(.medium)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .padding()
                        .background(musicService.isAuthorized ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!musicService.isAuthorized)
                    .padding(.horizontal)
                    
                    if wsManager.clientConnected && musicService.currentSong != nil {
                        Button(action: { startGame() }) {
                            Text("START GAME")
                                .font(.title3)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Start Server Button (Manual for now)
                    if !wsManager.isRunning {
                        Button("Start Server") {
                            wsManager.start()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSongPicker) {
            SongPickerView(selectedSong: $musicService.currentSong)
                .environmentObject(musicService)
        }
        .onAppear {
            wsManager.start()
        }
        .onChange(of: wsManager.shouldStartGame) { shouldStart in
            if shouldStart {
                startGame(isRemoteDebug: true)
                wsManager.shouldStartGame = false
            }
        }
    }
    
    func startGame(isRemoteDebug: Bool = false) {
        if isRemoteDebug {
            withAnimation {
                showingGame = true
            }
            return
        }
        
        guard let song = musicService.currentSong else { return }
        
        // Optimistic transition: Go to game screen immediately
        withAnimation {
            showingGame = true
        }
        
        Task {
            do {
                try await musicService.play(song: song)
            } catch {
                print("Error playing song: \(error)")
                // Optionally handle error (e.g. show alert in GameView), 
                // but for now keeping us in GameView checks connection at least.
            }
        }
    }
}
