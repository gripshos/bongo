import Foundation

struct BeatMap: Codable, Identifiable {
    var id: String { songId }
    let songId: String
    let songTitle: String
    let bpm: Double
    let notes: [Note]
    
    struct Note: Codable {
        let time: Double
        let side: Side
    }
    
    enum Side: String, Codable {
        case left
        case right
    }
}
