import SwiftUI

enum GameDifficulty: String, CaseIterable, Identifiable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var id: String { rawValue }
}

struct BPMConfigView: View {
    @Binding var bpm: Double
    @Binding var difficulty: GameDifficulty
    let song: BongoSong?
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    // Tap-to-detect BPM
    @State private var tapTimes: [Date] = []
    @State private var estimatedFromTaps: Double?
    @State private var showTapFeedback = false

    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Song Info
                if let song = song {
                    VStack(spacing: 8) {
                        Text(song.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        Text(song.artist)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                }

                // BPM Display
                VStack(spacing: 8) {
                    Text("\(Int(bpm))")
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Text("BPM")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }

                // Tap to detect BPM
                Button(action: recordTap) {
                    VStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                            .scaleEffect(showTapFeedback ? 0.9 : 1.0)

                        Text("TAP TO DETECT BPM")
                            .font(.headline)
                            .fontWeight(.bold)

                        if let estimated = estimatedFromTaps {
                            Text("Detected: ~\(Int(estimated)) BPM")
                                .font(.subheadline)
                                .foregroundColor(.green)
                        } else {
                            Text("Tap along with the beat")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(showTapFeedback ? Color.white : Color.clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal)

                // Reset taps button
                if !tapTimes.isEmpty {
                    Button("Reset Taps") {
                        tapTimes = []
                        estimatedFromTaps = nil
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                // Difficulty Picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("DIFFICULTY")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .tracking(2)

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(GameDifficulty.allCases) { diff in
                            Text(diff.rawValue).tag(diff)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Difficulty description
                    Text(difficultyDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)

                Spacer()

                // Start Game Button
                Button(action: {
                    onConfirm()
                    dismiss()
                }) {
                    Text("START GAME")
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Configure Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    var difficultyDescription: String {
        switch difficulty {
        case .easy:
            return "Quarter notes only - great for beginners"
        case .medium:
            return "Quarter and eighth notes - balanced challenge"
        case .hard:
            return "16th notes with syncopation - for experts"
        }
    }

    func recordTap() {
        let now = Date()
        tapTimes.append(now)

        // Visual feedback
        withAnimation(.easeOut(duration: 0.1)) {
            showTapFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeIn(duration: 0.1)) {
                showTapFeedback = false
            }
        }

        // Keep only last 8 taps
        if tapTimes.count > 8 {
            tapTimes.removeFirst()
        }

        // Calculate BPM from tap intervals (need at least 4 taps)
        if tapTimes.count >= 4 {
            var intervals: [TimeInterval] = []
            for i in 1..<tapTimes.count {
                intervals.append(tapTimes[i].timeIntervalSince(tapTimes[i-1]))
            }
            let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

            // Convert interval to BPM (60 seconds / interval = BPM)
            let detectedBPM = 60.0 / avgInterval

            // Clamp to reasonable range
            let clampedBPM = min(200, max(60, detectedBPM))
            estimatedFromTaps = clampedBPM
            bpm = clampedBPM
        }
    }
}

#Preview {
    BPMConfigView(
        bpm: .constant(120),
        difficulty: .constant(.medium),
        song: nil,
        onConfirm: {}
    )
}
