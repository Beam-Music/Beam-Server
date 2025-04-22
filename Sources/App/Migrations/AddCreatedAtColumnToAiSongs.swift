//
//  AddCreatedAtColumnToAiSongs.swift
//  Beam-Music-Server
//
//  Created by anonymous on 4/22/25.
//

import Fluent
import Vapor

struct AddCreatedAtColumnToAiSongs: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("ai_songs")
            .field("created_at", .datetime)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("ai_songs")
            .deleteField("created_at")
            .update()
    }
}
