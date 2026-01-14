import Foundation

enum AppState {
    case setup
    case connected
}

enum GameStatus {
    case idle
    case playing
    case finished
}

struct GameScore {
    var score: Int = 0
    var combo: Int = 0
    var maxCombo: Int = 0
    
    mutating func addHit(rating: HitRating) {
        combo += 1
        maxCombo = max(maxCombo, combo)
        
        switch rating {
        case .perfect: score += 100 * combo
        case .good: score += 75 * combo
        case .ok: score += 50 * combo
        case .miss: 
            combo = 0
        }
    }
    
    mutating func addMiss() {
        combo = 0
    }
}

enum HitRating: String {
    case perfect
    case good
    case ok
    case miss
}
