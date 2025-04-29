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
        self.id = try song.requireID()
        self.title = song.title
        self.artistName = artist.name
        self.genre = song.genre
        self.duration = song.duration
        self.artworkUrl = nil
        self.musicKitID = nil
        self.playbackStoreID = nil  // Initialize as nil, will be set by client
        
        let generated = song.isAIGenerated ?? false
        self.isAIGenerated = generated
        
        if generated {
            self.playbackUrl = aiSong?.fileUrl
        } else {
            self.playbackUrl = nil
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

