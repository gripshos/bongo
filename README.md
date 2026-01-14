# Bongo 🪘

**Bongo** is a dual-screen rhythm game that turns your iPhone into a motion controller and your web browser into the main game display. 

## Overview

- **Controller (iOS)**: Your iPhone detects taps (left/right) and handles music playback via Apple Music (MusicKit). It hosts a local WebSocket server to communicate with the display.
- **Display (Web)**: A web page running on your computer connects to the iPhone, rendering the note highway and providing visual feedback.

The two devices communicate over your local Wi-Fi network in real-time.

---

## Prerequisites

- **iPhone** running **iOS 17.0+**.
- **Apple Music Subscription** (required for MusicKit playback).
- **Mac** with **Xcode 15+** (to build the iOS app).
- **Web Browser** (Chrome, Safari, etc.) on a computer connected to the same Wi-Fi as the iPhone.

---

## Setup & Installation

### 1. iOS App (Controller)

1.  Clone this repository.
2.  Open the `BongoController` folder.
3.  Open `BongoController.xcodeproj` in **Xcode**.
    *   *Note: If the project file is missing, create a new iOS App project named "BongoController" and drag the source files into it.*
4.  **Add Dependencies**:
    *   The project uses [Telegraph](https://github.com/Building42/Telegraph) for WebSocket communication.
    *   If missing, go to `File > Add Package Dependencies` and add `https://github.com/Building42/Telegraph`.
5.  **Signing**:
    *   Select your Team in the "Signing & Capabilities" tab.
    *   Ensure the **MusicKit** and **Background Modes (Audio)** capabilities are enabled.
6.  **Build & Run** on your physical iPhone (Simulators may not support local networking or MusicKit fully).
7.  Grant permissions for **Local Network** and **Apple Music** when prompted.

### 2. Web Display

1.  Navigate to the `bongo-display` folder.
2.  Open `index.html` in your web browser.
    *   You can open it directly as a file, or host it with a simple server (e.g., `python3 -m http.server`).

---

## How to Play

1.  **Start the Server**: Open the Bongo app on your iPhone. It will automatically start the WebSocket server and display your **IP Address** (e.g., `ws://192.168.1.50:8080`).
2.  **Connect the Display**: On the web page on your computer, enter the WebSocket URL shown on your phone and click **Connect**.
3.  **Select a Song**: On your iPhone, tap "Select Song" and choose a track from your Apple Music library.
    *   *Note: For this MVP, only specific logic/beatmaps might be implemented for demo purposes.*
4.  **Start Game**: Tap **Start Game** on the iPhone.
5.  **Play**:
    *   Tap the **Left** side of your iPhone screen for blue notes.
    *   Tap the **Right** side of your iPhone screen for red notes.
    *   Try to hit the notes exactly when they reach the hit line on your computer screen!

---

## Architecture

*   **iOS**: Swift, SwiftUI, MusicKit, Telegraph (WebSocket Server).
*   **Web**: HTML5, CSS3, Vanilla JavaScript (WebSocket Client).
*   **Protocol**: JSON messages over WebSocket (`gameStart`, `sync`, `tap`, `gameEnd`).

## Development

- **Beat Maps**: The game currently relies on `beatmaps.json` stored in the iOS app bundle to map songs.
- **Latency**: The game includes a basic sync mechanism, but network latency can vary. Future improvements will include manual calibration.

---

_Built as an MVP demonstration of cross-device interactive web experiences._
