import Vapor
import Fluent

struct PlayableTrackDTO: Content {
    let id: UUID
    let title: String
    let artistName: String?
    let genre: String?
    let duration: Int?
    let artworkUrl: String?
    // TODO: 앨범 아트 URL (필요시 추가 로직)
    
    
    let isAIGenerated: Bool
    let playbackUrl: String?
    let musicKitID: String?
    let playbackStoreID: String?

    init(song: Song, artist: Artist, aiSong: AiSong?) throws {
        print("🎵 Creating PlayableTrackDTO")
        print("   Song: \(song.title)")
        print("   Artist: \(artist.name)")

        let isAI = song.isAIGenerated ?? false
        print("   Is AI Generated: \(isAI)")

        self.id = try song.requireID()
        self.title = song.title
        self.artistName = artist.name
        self.genre = song.genre
        self.duration = song.duration
        self.artworkUrl = nil // TODO: Implement artwork URL logic if needed

        self.isAIGenerated = isAI

        if isAI {
            print("   AI Song Data: \(aiSong != nil ? "Present" : "Not Present")")
            print("   Setting up AI song playback")
            self.playbackUrl = aiSong?.fileUrl
            self.musicKitID = nil
            self.playbackStoreID = nil

            if self.playbackUrl == nil {
                print("⚠️ Warning: AI song '\(song.title)' has no playback URL")
            } else {
                print("   Playback URL: \(self.playbackUrl!)")
            }
        } else {
            print("   Setting up MusicKit song")
            self.playbackStoreID = song.musicKitStoreID
            self.playbackUrl = nil
            self.musicKitID = nil

            if self.playbackStoreID == nil {
                print("⚠️ Warning: MusicKit song '\(song.title)' has no playbackStoreID")
            } else {
                print("   Playback Store ID: \(self.playbackStoreID!)")
            }
        }
    }
}

struct PlaylistSummaryDTO: Content {
    let id: UUID?
    let name: String
    let description: String?
    
    init(id: UUID?, name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

struct CreateUserPlaylistData: Content {
    var name: String
}

struct UpdateUserPlaylistData: Content {
    var name: String
}

