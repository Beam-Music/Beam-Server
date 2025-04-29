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
    let playbackStoreID: String?  // Added for MusicKit playback
    
    init(song: Song, artist: Artist, aiSong: AiSong?) throws {
        print("🎵 Creating PlayableTrackDTO")
        print("   Song: \(song.title)")
        print("   Artist: \(artist.name)")
        print("   Is AI Generated: \(song.isAIGenerated ?? false)")
        print("   AI Song Data: \(aiSong != nil ? "Present" : "Not Present")")
        
        self.id = try song.requireID()
        self.title = song.title
        self.artistName = artist.name
        self.genre = song.genre
        self.duration = song.duration
        self.artworkUrl = nil
        
        let isAI = song.isAIGenerated ?? false
        self.isAIGenerated = isAI
        
        if isAI {
            print("   Setting up AI song playback")
            self.playbackUrl = aiSong?.fileUrl
            self.musicKitID = nil
            self.playbackStoreID = nil
            
            if self.playbackUrl == nil {
                print("⚠️ Warning: AI song has no playback URL")
            } else {
                print("   Playback URL: \(self.playbackUrl!)")
            }
        } else {
            print("   Setting up MusicKit song")
            self.playbackUrl = nil
            self.musicKitID = nil
            self.playbackStoreID = nil
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

