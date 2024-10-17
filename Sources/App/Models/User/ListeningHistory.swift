//
//  File.swift
//  
//
//  Created by freed on 9/12/24.
//

import Fluent
import Vapor

final class ListeningHistory: Model, Content, @unchecked Sendable {
    static let schema = "listening_history"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @Parent(key: "song_id")
    var song: Song

    @Field(key: "listened_at")
    var listenedAt: Date

    @Field(key: "play_duration")
    var playDuration: Int

    init() { }

    init(id: UUID? = nil, userID: UUID, songID: UUID, listenedAt: Date, playDuration: Int) {
        self.id = id
        self.$user.id = userID
        self.$song.id = songID
        self.listenedAt = listenedAt
        self.playDuration = playDuration
    }
}

struct CreateListeningHistory: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("listening_history")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("song_id", .uuid, .required, .references("songs", "id", onDelete: .cascade))
            .field("listened_at", .datetime, .required)
            .field("play_duration", .int, .required)
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("listening_history").delete()
    }
}

