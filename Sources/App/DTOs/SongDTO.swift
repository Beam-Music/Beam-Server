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
        // TODO: 필요시 MusicKit 등에서 가져오는 로직 추가

        self.isAIGenerated = song.isAIGenerated ?? false

        if self.isAIGenerated {
            if let aiSong = aiSong {
                // AiSong 데이터가 있으면 URL 생성 (Endpoints.baseURL 필요)
//                self.playbackUrl = Endpoints.baseURL + aiSong.fileUrl // aiSong.fileUrl이 "/"로 시작한다고 가정
                self.playbackUrl = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"

            } else {
                self.playbackUrl = nil // 서버 중단 방지
            }
            self.musicKitID = nil
        } else {
            self.playbackUrl = nil
            // Apple Music ID 처리 (현재는 Song UUID 사용 - 실제 구현에 맞게 수정 필요)
            self.musicKitID = song.id?.uuidString
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

