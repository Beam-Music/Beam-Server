//
//  CreateUserPlaylist.swift
//  Beam-Music-Server
//
//  Created by freed on 9/26/24.
//

// CreateUserPlaylist.swift

import Fluent

struct CreateUserPlaylist: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("user_playlists")
            .id()
            .field("name", .string, .required)
            .field("user_id", .uuid, .required, .references("users", "id"))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("user_playlists").delete()
    }
}

struct CreatePlaylistSong: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("playlist_songs")
            .id()
            .field("playlist_id", .uuid, .required, .references("user_playlists", "id"))
            .field("song_id", .uuid, .required, .references("songs", "id"))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("playlist_songs").delete()
    }
}
