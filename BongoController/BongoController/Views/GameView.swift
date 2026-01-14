import SwiftUI
import MusicKit
import Combine

struct GameView: View {
    @ObservedObject var musicService: MusicService
    @ObservedObject var wsManager: WebSocketServerManager
    
    @State private var score = 0
    @State private var combo = 0
    @State private var timer: Timer?
    @State private var beatMap: BeatMap?
    
    var body: some View {
        ZStack {
            TapZoneView(onTapLeft: { handleTap(side: .left) },
                        onTapRight: { handleTap(side: .right) })
            
            VStack {
                HStack {
                    VStack(alignment: .leading) {
                        Text("SCORE")
                            .font(.caption)
                            .bold()
                        Text("\(score)")
                            .font(.title)
                            .monospacedDigit()
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("COMBO")
                            .font(.caption)
                            .bold()
                        Text("\(combo)")
                            .font(.title)
                            .foregroundColor(.purple)
                    }
                }
                .padding()
                .background(Material.thin)
                
                Spacer()
                
                // Stop Button
                Button(action: endGame) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white)
                        .padding()
                }
            }
        }
        .onAppear {
            startGame()
        }
        .onDisappear {
            endGame()
        }
    }
    
    func startGame() {
        // Prepare beatmap
        if let data = loadBeatMap() {
            self.beatMap = data
            
            // Send GameStart
            let startMsg = GameStartMessage(
                type: "gameStart",
                songTitle: musicService.currentSong?.title ?? "Unknown",
                bpm: data.bpm,
                beatMap: data.notes
            )
            wsManager.send(message: startMsg)
        }
        
        // Start Sync Timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            sendSync()
        }
    }
    
    func sendSync() {
        let time = musicService.playbackTime
        let msg = SyncMessage(type: "sync", playbackTime: time)
        wsManager.send(message: msg)
    }
    
    func handleTap(side: BeatMap.Side) {
        let time = musicService.playbackTime
        // Send tap to web
        let msg = TapMessage(type: "tap", side: side.rawValue, playbackTime: time)
        wsManager.send(message: msg)
        
        // Local logic (simplified for MVP: just track taps, real scoring is on Web for visual feedback or shared)
        // We will trust the Web to show feedback primarily, but we update score locally if we wanted full logic here.
        // For MVP, iOS is controller.
    }
    
    func endGame() {
        timer?.invalidate()
        timer = nil
        musicService.stop()
        wsManager.send(message: GameEndMessage(type: "gameEnd", finalScore: score))
        // Dismiss view logic handled by parent state usually
    }
    
    func loadBeatMap() -> BeatMap? {
        // Load from bundle
        guard let url = Bundle.main.url(forResource: "beatmaps", withExtension: "json") else {
             print("Error: beatmaps.json not found in Bundle")
             return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let maps = try JSONDecoder().decode([BeatMap].self, from: data)
            return maps.first
        } catch {
             print("Error decoding beatmaps.json: \(error)")
             return nil
        }
    }
}

// Protocol structs for JSON
struct GameStartMessage: Codable {
    let type: String
    let songTitle: String
    let bpm: Double
    let beatMap: [BeatMap.Note]
}

struct SyncMessage: Codable {
    let type: String
    let playbackTime: Double
}

struct TapMessage: Codable {
    let type: String
    let side: String
    let playbackTime: Double
}

struct GameEndMessage: Codable {
    let type: String
    let finalScore: Int
}
