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
    var id: UUID?

    @Field(key: "title")
    var title: String
    
    @Field(key: "genre")
    var genre: String

    @Field(key: "release_date")
    var releaseDate: Date

    @Field(key: "duration")
    var duration: Int
    
    @Field(key: "is_ai_generated")
    var isAIGenerated: Bool

    @Parent(key: "artist_id")
    var artist: Artist

    init() { }

    init(id: UUID? = nil, title: String, genre: String, releaseDate: Date, duration: Int, artistID: UUID, isAIGenerated: Bool = false) {
        self.id = id
        self.title = title
        self.genre = genre
        self.releaseDate = releaseDate
        self.duration = duration
        self.$artist.id = artistID
        self.isAIGenerated = isAIGenerated
    }
}

final class AiSong: Model, Content, @unchecked Sendable {
    static let schema = "ai_songs"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String
    
    @Field(key: "genre")
    var genre: String

    @Field(key: "release_date")
    var releaseDate: Date

    @Field(key: "duration")
    var duration: Int
    
    @Field(key: "is_ai_generated")
    var isAIGenerated: Bool
    
    @Field(key: "file_path")
    var filePath: String

    @OptionalParent(key: "song_id")
    var song: Song?
    
    init() { }

    init(id: UUID? = nil, title: String, genre: String, releaseDate: Date, duration: Int, isAIGenerated: Bool = true, filePath: String, songID: UUID? = nil) {
        self.id = id
        self.title = title
        self.genre = genre
        self.releaseDate = releaseDate
        self.duration = duration
        self.isAIGenerated = isAIGenerated
        self.filePath = filePath
        if let songID = songID {
            self.$song.id = songID
        }
    }
}
