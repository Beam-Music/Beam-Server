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
    
    init(song: Song, artist: Artist, aiSong: AiSong?) throws {
        self.id = try song.requireID()
        self.title = song.title
        self.artistName = artist.name
        self.genre = song.genre
        self.duration = song.duration
        self.artworkUrl = nil
        self.musicKitID = nil
        
        self.isAIGenerated = song.isAIGenerated ?? false
        
        if self.isAIGenerated {
            if let aiSong = aiSong {
                self.playbackUrl = aiSong.fileUrl
            } else {
                self.playbackUrl = nil
            }
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


//struct Endpoints {
//    // ifconfig로 확인된 IP 주소 사용
//    static let baseURL = "http://192.168.0.185:8080" // 실제 IP로 변경 필요
//}

struct CreateUserPlaylistData: Content {
    var name: String
}

// PUT /user-playlists/:playlistID 요청 본문을 위한 DTO
struct UpdateUserPlaylistData: Content {
    var name: String
    // 필요하다면 다른 업데이트 가능한 필드 추가
}

