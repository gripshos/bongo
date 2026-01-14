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
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    
                    if wsManager.clientConnected && musicService.currentSong != nil {
                        Button(action: startGame) {
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
        }
        .onAppear {
            wsManager.start()
        }
    }
    
    func startGame() {
        guard let song = musicService.currentSong else { return }
        Task {
            do {
                try await musicService.play(song: song)
                withAnimation {
                    showingGame = true
                }
            } catch {
                print("Error playing song: \(error)")
            }
        }
    }
}
