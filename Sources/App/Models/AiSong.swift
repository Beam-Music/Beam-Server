//
//  AiSong.swift
//  Beam-Music-Server
//
//  Created by anonymous on 4/22/25.
//

import Fluent
import Vapor

final class AiSong: Model, Content {
    static let schema = "ai_songs"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String

    @OptionalField(key: "genre")
    var genre: String?

    @OptionalField(key: "release_date")
    var releaseDate: Date?

    @Field(key: "duration")
    var duration: Int

    @Field(key: "is_ai_generated")
    var isAiGenerated: Bool

    @Field(key: "file_url")
    var fileUrl: String

    @Parent(key: "song_id")
    var song: Song

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    var loadedTitle: String?
    var loadedArtistName: String?
    var loadedGenre: String?

    init() { }

    init(id: UUID? = nil,
         title: String,
         genre: String? = nil,
         releaseDate: Date? = nil,
         duration: Int,
         isAiGenerated: Bool,
         fileUrl: String,
         songId: Song.IDValue) {
        self.id = id
        self.title = title
        self.genre = genre
        self.releaseDate = releaseDate
        self.duration = duration
        self.isAiGenerated = isAiGenerated
        self.fileUrl = fileUrl
        self.$song.id = songId
    }
}

extension AiSong {
    @discardableResult
    func loadSongDetails(on database: Database) async throws -> AiSong {
        guard let relatedSong = try await Song.find(self.$song.id, on: database) else {
            self.loadedTitle = nil
            self.loadedArtistName = nil
            self.loadedGenre = nil
            return self
        }

        try await relatedSong.$artist.load(on: database)

        self.loadedTitle = relatedSong.title
        self.loadedArtistName = relatedSong.artist.name
        self.loadedGenre = relatedSong.genre

        return self 
    }
}
