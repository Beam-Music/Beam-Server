//
//  File.swift
//  
//
//  Created by freed on 9/12/24.
//

import Fluent
import Vapor

final class UserSongPreference: Model, Content, @unchecked Sendable {
    static let schema = "user_song_preferences"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "song_id")
    var song: Song

    @Field(key: "rating")
    var rating: Int

    init() { }

    init(id: UUID? = nil, userID: UUID, songID: UUID, rating: Int) {
        self.id = id
        self.$user.id = userID
        self.$song.id = songID
        self.rating = rating
    }
}

struct CreateUserSongPreference: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("user_song_preferences")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("song_id", .uuid, .required, .references("songs", "id", onDelete: .cascade))
            .field("rating", .int, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("user_song_preferences").delete()
    }
}

