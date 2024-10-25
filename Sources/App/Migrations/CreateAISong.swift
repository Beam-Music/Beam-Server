//
//  CreateAIsong.swift
//  Beam-Music-Server
//
//  Created by freed on 10/25/24.
//

//  CreateAISong.swift

import Fluent

struct CreateAISong: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("ai_songs")
            .id()
            .field("title", .string, .required)
            .field("artist", .string, .required)
            .field("genre", .string)
            .field("release_date", .date)
            .field("duration", .int)
            .field("file_path", .string, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("ai_songs").delete()
    }
}
