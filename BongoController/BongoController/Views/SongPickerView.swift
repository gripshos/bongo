import SwiftUI
import MusicKit

struct SongPickerView: View {
    @Binding var selectedSong: Song?
    @Environment(\.dismiss) var dismiss
    @State private var songs: MusicItemCollection<Song> = []
    
    var body: some View {
        NavigationView {
            List(songs) { song in
                Button(action: {
                    selectedSong = song
                    dismiss()
                }) {
                    HStack {
                        AsyncImage(url: song.artwork?.url(width: 50, height: 50))
                            .frame(width: 50, height: 50)
                            .cornerRadius(5)
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.headline)
                            Text(song.artistName)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Select Music")
            .task {
                await loadLibrarySongs()
            }
        }
    }
    
    func loadLibrarySongs() async {
        do {
            // Just load recently added for MVP simple access
            let request = MusicLibraryRequest<Song>()
            let response = try await request.response()
            self.songs = response.items
        } catch {
            print("Failed to load songs: \(error)")
        }
    }
}
