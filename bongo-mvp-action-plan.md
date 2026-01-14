# Bongo Game MVP - Development Action Plan

## Project Overview

Build a rhythm game where the player taps left/right sides of their iPhone to hit notes in sync with music. The iPhone acts as the controller while a web browser displays the game visuals. Music plays from Apple Music on the phone and is AirPlayed to the TV/speakers.

## Target Architecture

```
iPhone App (Controller)          Web Display (Browser)
┌─────────────────────┐         ┌─────────────────────┐
│ - Left/right tap    │ ──────▶ │ - Note highway      │
│   detection         │WebSocket│ - Hit/miss feedback │
│ - MusicKit playback │ ◀────── │ - Score display     │
│ - Game state mgmt   │         │ - Bongo animations  │
│ - Hosts WebSocket   │         │                     │
└─────────────────────┘         └─────────────────────┘
```

---

## Phase 1: iOS App Foundation

### 1.1 Create Xcode Project
- Create new iOS app project named "BongoController"
- Set minimum deployment target to iOS 17
- Add MusicKit capability in Signing & Capabilities
- Add Local Network Usage description to Info.plist
- Add Microphone usage description to Info.plist (for future clap feature)

### 1.2 Build Tap Detection View
- Create full-screen SwiftUI view divided into two tap zones (left half, right half)
- On tap, determine which zone was hit based on gesture location
- Fire an event with: `{ side: "left" | "right", timestamp: Double }`
- Add visual feedback on tap (brief highlight of the tapped zone)
- Timestamp should use `CACurrentMediaTime()` for precision

### 1.3 Integrate MusicKit
- Request MusicKit authorization on app launch
- Create a MusicPlayer instance using `ApplicationMusicPlayer.shared`
- Build simple UI to select a song from the user's library
- Implement play/pause controls
- Expose current playback time via `ApplicationMusicPlayer.shared.playbackTime`

### 1.4 Implement WebSocket Server
- Add a lightweight WebSocket server library (recommend using Swift NIO or a simpler wrapper like Telegraph)
- Host WebSocket server on a fixed port (e.g., 8080)
- Display the device's local IP address on screen so user can connect browser
- Broadcast messages to all connected clients

### 1.5 Define Message Protocol
Implement these JSON message types sent from iPhone to browser:

```json
// Game start - sent when player begins a song
{
  "type": "gameStart",
  "songTitle": "Song Name",
  "bpm": 120,
  "beatMap": [
    { "time": 0.5, "side": "left" },
    { "time": 1.0, "side": "right" },
    { "time": 1.5, "side": "left" }
  ]
}

// Playback sync - sent every 100ms during gameplay
{
  "type": "sync",
  "playbackTime": 12.345
}

// Tap event - sent immediately when player taps
{
  "type": "tap",
  "side": "left",
  "playbackTime": 12.567
}

// Game end
{
  "type": "gameEnd",
  "finalScore": 1250
}
```

---

## Phase 2: Web Display Application

### 2.1 Set Up Web Project
- Create simple HTML/CSS/JavaScript project (no framework needed for MVP)
- Single index.html file with embedded styles and scripts is fine
- Host locally or just open file directly in browser during development

### 2.2 Build WebSocket Client
- Connect to iPhone's WebSocket server using URL entered by user (e.g., `ws://192.168.1.50:8080`)
- Handle connection state (connecting, connected, disconnected)
- Parse incoming JSON messages and route to appropriate handlers

### 2.3 Create Game Display
- Full-screen display with two "lanes" (left and right)
- Notes scroll down from top toward a "hit zone" at bottom
- Visual design: simple circles or rectangles for notes, distinct colors for left (blue) vs right (red)
- Hit zone displayed as a horizontal line near bottom of screen

### 2.4 Implement Note Rendering
- On `gameStart` message, load the beat map into memory
- Calculate note positions based on: current playback time, note's target time, and scroll speed
- Notes should appear ~2 seconds before their hit time and scroll down
- Remove notes from display after they pass the hit zone (missed) or are hit

### 2.5 Implement Hit Detection Display
- On `tap` message, check if any note of matching side is within hit window (±150ms)
- Display hit feedback: "Perfect!" / "Good!" / "Miss!" based on timing accuracy
- Animate the bongo (simple scale/color pulse on the hit side)
- Update and display running score

### 2.6 Build Score Display
- Show current combo (consecutive hits)
- Show total score
- On `gameEnd`, display final results screen

---

## Phase 3: Game Logic & Beat Maps

### 3.1 Implement Beat Map Data Structure
On iOS side, define a structure for beat maps:

```swift
struct BeatMap: Codable {
    let songId: String  // Apple Music song ID
    let bpm: Double
    let notes: [Note]
    
    struct Note: Codable {
        let time: Double  // seconds from song start
        let side: String  // "left" or "right"
    }
}
```

### 3.2 Create Test Beat Map
- Manually create a beat map for one song that is in your Apple Music library
- Start with a simple, recognizable song with clear beats
- Map ~30-60 seconds of the song with alternating left/right notes on the beat
- Store as JSON file bundled with the iOS app

### 3.3 Implement Scoring Logic (iOS side)
- When tap received, find closest note within hit window (±200ms)
- Score based on accuracy:
  - Perfect (±50ms): 100 points
  - Good (±100ms): 75 points  
  - OK (±150ms): 50 points
  - Miss: 0 points, break combo
- Track combo multiplier: combo count × base points
- Send score updates to web display

### 3.4 Implement Game Flow
1. App launches → show song selection
2. Player selects song → load beat map (if available) or show "no beat map" message
3. Player taps "Start" → send `gameStart` to web display
4. 3-second countdown on both screens
5. Music begins, sync messages start flowing
6. Player taps along with notes
7. Song ends → send `gameEnd` with final score
8. Show results on both screens

---

## Phase 4: Polish & Testing

### 4.1 Latency Calibration
- Add a calibration screen to iOS app
- Play a click track, have user tap along
- Measure average offset between expected and actual tap times
- Apply offset to hit detection calculations

### 4.2 Network Resilience  
- Handle WebSocket disconnection gracefully
- Show reconnection UI
- Pause game if connection lost mid-song

### 4.3 Visual Polish
- Add bongo drum graphics to web display
- Animate drums when hit
- Add particle effects for perfect hits
- Smooth note scrolling at 60fps

### 4.4 Audio Feedback
- Play hit sounds on successful taps (on iPhone)
- Different sounds for perfect/good/miss

---

## Technical Constraints

- **iOS version**: 17.0+
- **Browser support**: Safari and Chrome (modern versions)
- **Network**: iPhone and browser must be on same local WiFi network
- **Apple Music**: User must have Apple Music subscription for MusicKit playback

---

## File Structure

### iOS App
```
BongoController/
├── BongoControllerApp.swift
├── ContentView.swift
├── Views/
│   ├── TapZoneView.swift
│   ├── SongPickerView.swift
│   └── GameView.swift
├── Models/
│   ├── BeatMap.swift
│   └── GameState.swift
├── Services/
│   ├── MusicService.swift
│   └── WebSocketServer.swift
├── Resources/
│   └── beatmaps.json
└── Info.plist
```

### Web Display
```
bongo-display/
├── index.html
├── style.css
├── game.js
└── assets/
    └── bongo-drum.png
```

---

## Definition of Done (MVP)

The MVP is complete when:
- [ ] iPhone app connects to Apple Music and plays a song
- [ ] iPhone app detects left/right taps with visual feedback
- [ ] iPhone hosts WebSocket server and displays connection URL
- [ ] Web page connects to iPhone via WebSocket
- [ ] Web page displays scrolling notes synchronized to music
- [ ] Taps on iPhone register as hits/misses on web display
- [ ] Score is tracked and displayed
- [ ] At least one song has a working beat map
- [ ] Game can be played from start to finish without crashes

---

## Out of Scope for MVP

- Clap detection
- Multiple songs with beat maps
- Beat map editor
- Online leaderboards
- tvOS native app
- macOS native app
- Automatic beat map generation from audio
- Multiplayer
