import Foundation

struct BeatMapGenerator {
    /// Generates a beatmap algorithmically based on BPM, duration, and difficulty
    /// - Parameters:
    ///   - songId: Unique identifier for the song
    ///   - songTitle: Display title of the song
    ///   - bpm: Beats per minute (tempo)
    ///   - duration: Song duration in seconds
    ///   - difficulty: Difficulty level affecting note density
    /// - Returns: A generated BeatMap
    static func generate(
        songId: String,
        songTitle: String,
        bpm: Double,
        duration: TimeInterval,
        difficulty: GameDifficulty
    ) -> BeatMap {
        // Calculate beat interval in seconds
        let beatInterval = 60.0 / bpm

        var notes: [BeatMap.Note] = []

        // Start 2 seconds into song, end 2 seconds before end
        let startTime = 2.0
        let endTime = max(startTime + 1, duration - 2.0)
        var currentTime = startTime

        // Track pattern state for variation
        var noteCount = 0
        var lastSide: BeatMap.Side = .left

        while currentTime < endTime {
            // Determine note side - alternate with occasional patterns
            let side: BeatMap.Side
            if noteCount % 8 == 7 {
                // Every 8th note, repeat the same side for emphasis
                side = lastSide
            } else {
                // Alternate sides
                side = lastSide == .left ? .right : .left
            }

            notes.append(BeatMap.Note(time: currentTime, side: side))
            lastSide = side
            noteCount += 1

            // Add additional notes based on difficulty
            switch difficulty {
            case .easy:
                // Quarter notes only - one note per beat
                currentTime += beatInterval

            case .medium:
                // Quarter + occasional eighth notes
                currentTime += beatInterval

                // Add eighth note on every 4th beat for variation
                if noteCount % 4 == 0 && currentTime + beatInterval * 0.5 < endTime {
                    let offbeatSide: BeatMap.Side = side == .left ? .right : .left
                    notes.append(BeatMap.Note(time: currentTime - beatInterval * 0.5, side: offbeatSide))
                }

            case .hard:
                // 16th notes with syncopation
                let subBeatInterval = beatInterval / 2.0

                // Add syncopated notes
                if noteCount % 2 == 0 && currentTime + subBeatInterval < endTime {
                    // Add off-beat note
                    let offbeatSide: BeatMap.Side = side == .left ? .right : .left
                    notes.append(BeatMap.Note(time: currentTime + subBeatInterval, side: offbeatSide))
                }

                // Every 4th beat, add a double hit (both sides close together)
                if noteCount % 4 == 3 && currentTime + subBeatInterval * 0.5 < endTime {
                    let doubleSide: BeatMap.Side = side == .left ? .right : .left
                    notes.append(BeatMap.Note(time: currentTime + subBeatInterval * 0.25, side: doubleSide))
                }

                currentTime += subBeatInterval * 1.5 // Faster progression for hard mode
            }
        }

        // Sort notes by time to ensure proper ordering
        let sortedNotes = notes.sorted { $0.time < $1.time }

        return BeatMap(
            songId: songId,
            songTitle: songTitle,
            bpm: bpm,
            notes: sortedNotes
        )
    }

    /// Generates a simple test beatmap for debugging
    static func generateTestMap(duration: TimeInterval = 30.0) -> BeatMap {
        return generate(
            songId: "test",
            songTitle: "Test Beat",
            bpm: 120,
            duration: duration,
            difficulty: .medium
        )
    }
}
