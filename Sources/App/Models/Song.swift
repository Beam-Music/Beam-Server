//
//  File.swift
//
//
//  Created by freed on 9/12/24.
//
import Fluent
import Vapor

final class Song: Model, Content, @unchecked Sendable {
    static let schema = "songs"

    @ID(key: .id)
    var id: UUID? // ID 타입 확인

    @Field(key: "title")
    var title: String

    // --- 수정: Artist 모델과의 관계 설정 ---
    @Parent(key: "artist_id") // DB의 artist_id 컬럼 사용
    var artist: Artist         // Artist 모델 필요 (Artist.swift)
    // --- 수정 완료 ---

    @Field(key: "genre")
    var genre: String // DB 타입과 일치하는지 확인

    @Field(key: "release_date")
    var releaseDate: Date? // DB 타입과 일치하는지 확인 (Date? 또는 String?)

    @Field(key: "duration")
    var duration: Int? // DB 타입과 일치하는지 확인 (Int? 또는 Double?)

    @Field(key: "is_ai_generated")
    var isAIGenerated: Bool? // DB 타입과 일치하는지 확인 (Bool?)

    // --- 추가: 타임스탬프 필드 ---
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    // --- 추가 완료 ---

    init() { }

    // --- 수정: init 메소드 변경 ---
    // artist: String 대신 artistID: Artist.IDValue 받도록 수정
    init(id: UUID? = nil, title: String, artistID: Artist.IDValue, genre: String,
         releaseDate: Date? = nil, duration: Int? = nil, isAIGenerated: Bool? = false) {
        self.id = id
        self.title = title
        self.$artist.id = artistID // @Parent 관계 ID 설정
        self.genre = genre
        self.releaseDate = releaseDate
        self.duration = duration
        self.isAIGenerated = isAIGenerated
    }
    // --- 수정 완료 ---
}

// --- 참고: Artist 모델 예시 (Artist.swift 파일에 정의 필요) ---
/*
final class Artist: Model, Content {
    static let schema = "artists" // 실제 아티스트 테이블 이름

    @ID(key: .id)
    var id: UUID? // 또는 Int? 등 ID 타입

    @Field(key: "name")
    var name: String

    // ... 다른 필드들 ...

    init() { }

    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}
*/
final class AiSong: Model, Content {
    static let schema = "ai_songs"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "song_id")
    var songId: UUID

    @Field(key: "file_url")
    var fileUrl: String

    @Timestamp(key: "created_at", on: .create) // @Field 대신 @Timestamp 사용 권장
    var createdAt: Date?

    // Virtual properties - not stored in the database
    var title: String?
    var artist: String? // 아티스트 이름을 저장할 가상 프로퍼티
    var genre: String?

    init() { }

    init(id: UUID? = nil, songId: UUID, fileUrl: String) {
        self.id = id
        self.songId = songId
        self.fileUrl = fileUrl
    }
}


// --- 수정된 Extension ---
extension AiSong {
    // EventLoopFuture 대신 async/await 사용 (최신 Vapor/Fluent 스타일)
    func loadSongDetails(on database: Database) async throws -> AiSong {
        guard let song = try await Song.find(self.songId, on: database) else {
            // 노래를 찾지 못한 경우 처리 (예: 로깅 또는 기본값 설정)
            return self
        }

        // 관련 아티스트 정보 로드
        try await song.$artist.load(on: database)

        // 가상 프로퍼티 채우기
        self.title = song.title
        self.artist = song.artist.name // Artist 모델에 'name' 필드가 있다고 가정
        self.genre = song.genre

        return self
    }

    // 기존 EventLoopFuture 방식 (참고용)
    // func loadSongDetails(on database: Database) -> EventLoopFuture<AiSong> {
    //     Song.find(self.songId, on: database)
    //         .flatMap { optionalSong -> EventLoopFuture<Song?> in
    //             guard let song = optionalSong else {
    //                 return database.eventLoop.makeSucceededFuture(nil) // 노래 없으면 nil 반환
    //             }
    //             // 아티스트 관계 로드
    //             return song.$artist.load(on: database).map { song }
    //         }
    //         .map { optionalLoadedSong in
    //             if let song = optionalLoadedSong {
    //                 self.title = song.title
    //                 self.artist = song.artist.name // Artist 모델에 'name' 필드가 있다고 가정
    //                 self.genre = song.genre
    //             }
    //             return self
    //         }
    // }
}
