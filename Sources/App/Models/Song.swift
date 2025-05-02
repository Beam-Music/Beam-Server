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

    @Parent(key: "artist_id")
    var artist: Artist

    @Field(key: "genre")
    var genre: String

    @OptionalField(key: "release_date")
    var releaseDate: Date?

    @OptionalField(key: "duration")
    var duration: Int?

    @OptionalField(key: "is_ai_generated")
    var isAIGenerated: Bool?

    @OptionalField(key: "music_kit_store_id")
    var musicKitStoreID: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(id: UUID? = nil, title: String, artistID: Artist.IDValue, genre: String,
         releaseDate: Date? = nil, duration: Int? = nil, isAIGenerated: Bool? = false,
         musicKitStoreID: String? = nil) {
        self.id = id
        self.title = title
        self.$artist.id = artistID
        self.genre = genre
        self.releaseDate = releaseDate
        self.duration = duration
        self.isAIGenerated = isAIGenerated
        self.musicKitStoreID = musicKitStoreID
    }
}
