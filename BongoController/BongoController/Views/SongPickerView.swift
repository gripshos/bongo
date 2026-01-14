import SwiftUI

struct SongPickerView: View {
    @Binding var selectedSong: BongoSong?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var musicService: MusicService
    @State private var songs: [BongoSong] = []
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            List(songs) { song in
                Button(action: {
                    selectedSong = song
                    dismiss()
                }) {
                    HStack {
                        AsyncImage(url: song.artworkURL) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 50, height: 50)
                        .cornerRadius(5)
                        
                        VStack(alignment: .leading) {
                            Text(song.title)
                                .font(.headline)
                            Text(song.artist)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .onChange(of: searchText) {
                Task {
                    self.songs = await musicService.search(query: searchText)
                }
            }
            .navigationTitle("Select Music")
            .task {
               // Load initial
               self.songs = await musicService.search(query: "")
            }
        }
    }
}
