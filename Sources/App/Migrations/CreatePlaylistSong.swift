//
//  CreatePlaylistSong.swift
//  Beam-Music-Server
//
//  Created by freed on 9/26/24.
//

import Fluent

struct AddOrderToPlaylistSong: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("playlist_songs")
            .field("order", .int, .required, .sql(.default(0)))
            .update()
    }
    func revert(on database: Database) async throws {
        try await database.schema("playlist_songs")
            .deleteField("order")
            .update()
    }
}

