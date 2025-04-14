//
//  UpdateAiSongsTable.swift
//  Beam-Music-Server
//
//  Created by anonymous on 4/11/25.
//

import Fluent

struct UpdateAiSongsTable: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("ai_songs")
            .field("title", .string, .required)
            .field("artist", .string, .required)
            .field("genre", .string)
            .field("generated_at", .datetime, .required)
            .field("server_path", .string, .required)
            .field("is_ai_generated", .bool, .required)
            .field("song_id", .uuid)
            .update()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.eventLoop.makeSucceededFuture(())
    }
}
