import SwiftUI
import MusicKit
import Combine

struct GameView: View {
    @ObservedObject var musicService: MusicService
    @ObservedObject var wsManager: WebSocketServerManager
    var bpm: Double = 120
    var difficulty: GameDifficulty = .medium

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
        // Generate beatmap dynamically based on song and settings
        let song = musicService.currentSong
        let songDuration = song?.duration ?? 60.0

        let generatedMap = BeatMapGenerator.generate(
            songId: song?.id ?? "unknown",
            songTitle: song?.title ?? "Unknown",
            bpm: bpm,
            duration: songDuration,
            difficulty: difficulty
        )
        self.beatMap = generatedMap

        // Send GameStart with song duration for progress bar
        let startMsg = GameStartMessage(
            type: "gameStart",
            songTitle: generatedMap.songTitle,
            bpm: generatedMap.bpm,
            beatMap: generatedMap.notes,
            songDuration: songDuration
        )
        wsManager.send(message: startMsg)

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
}

// Protocol structs for JSON
struct GameStartMessage: Codable {
    let type: String
    let songTitle: String
    let bpm: Double
    let beatMap: [BeatMap.Note]
    let songDuration: Double
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
