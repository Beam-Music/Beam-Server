//
//  CreateAISong.swift
//  Beam-Music-Server
//
//  Created by anonymous on 4/9/25.
//

import Fluent

struct CreateAISong: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("ai_songs")
            .id()
            .field("title", .string, .required)
            .field("genre", .string)
            .field("release_date", .date)
            .field("duration", .int, .required)
            .field("is_ai_generated", .bool, .required)
            .field("file_url", .string, .required) 
            .field("song_id", .uuid, .references("songs", "id"))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("ai_songs").delete()
    }
}
