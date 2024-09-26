//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//

import Fluent

struct CreateSong: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("songs")
            .id()
            .field("title", .string, .required)
            .field("artist_id", .uuid, .required, .references("artists", "id"))
            .field("artist", .string, .required)
            .field("genre", .string)
            .field("release_date", .date)
            .field("duration", .int)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("songs").delete()
    }
}
