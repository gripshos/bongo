# Bongo iOS App Setup Guide

Since I cannot generate the Xcode project file directly, follow these steps to assemble the app from the files I've created.

## 1. Create the Project
1. Open **Xcode**.
2. Click **Create New Project**.
3. Select **iOS** -> **App**.
4. Product Name: `BongoController`
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Save it in `/Users/stevengripshover/Documents/Development/bongo/` (overwrite the folder if needed, or just merge).
   - *Tip: If Xcode asks to replace the folder I created, say YES or Merge. If it makes a subfolder, just move my files into it.*
   - **Better approach**: Create the project in a temporary location, then copy the `.xcodeproj` file and the `BongoController` folder structure I created into it, or drag my files into the project navigator.

## 2. Import Files
1. In the Xcode Project Navigator (left sidebar), select the `BongoController` folder.
2. **Delete** the default `ContentView.swift` and `dApp.swift` if they exist.
3. **Right-click** on the `BongoController` folder in Xcode -> **Add Files to "BongoController"**.
4. Select all the files and folders I generated inside `BongoController/`:
   - `BongoControllerApp.swift`
   - `ContentView.swift`
   - `Views/`
   - `Models/`
   - `Services/`
   - `Resources/`
   - `Info.plist` (Replace the default one)
5. Make sure "Copy items if needed" is **unchecked** (since they are already there) and "Create groups" is selected.

## 3. Add Dependencies
1. In Xcode, go to **File** -> **Add Package Dependencies...**
2. Search for: `https://github.com/Building42/Telegraph`
3. Click **Add Package**.
4. When asked, add the **Telegraph** library to the **BongoController** target.

## 4. Include Resources
1. Click on the project file (blue icon) at the top of the navigator.
2. Select the **BongoController** target.
3. Go to **Build Phases**.
4. Expand **Copy Bundle Resources**.
5. Ensure `beatmaps.json` is in this list. If not, click `+` and add it.

## 5. Capabilities
1. Go to the **Signing & Capabilities** tab.
2. Click `+ Capability`.
3. Add **MusicKit** (Note: You may need a provisioning profile that supports this).
4. Add **Background Modes** and check **Audio, AirPlay, and Picture in Picture**.

## 6. Build & Run
1. Connect your iPhone.
2. Select your iPhone as the run destination.
3. **Run (Cmd+R)**.
4. Accept the permissions on your phone when prompted.

---

## Web Display
To run the web display:
1. Open `bongo-display/index.html` in Chrome or Safari on your computer.
2. Enter the IP address shown on your iPhone app.
3. Click Connect.
