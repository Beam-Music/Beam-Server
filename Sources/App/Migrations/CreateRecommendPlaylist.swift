//
//  CreateRecommendPlaylist.swift
//  Beam-Music-Server
//
//  Created by freed on 10/13/24.
//

import Fluent

struct CreateRecommendPlaylist: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("playlist_recommendation")
            .id()
            .field("name", .string, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("playlist_recommendation").delete()
    }
}

struct CreateRecommendPlaylistSong: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("recommend_playlists_songs")
            .id()
            .field("playlist_id", .uuid, .required, .references("playlist_recommendation", "id"))
            .field("song_id", .uuid, .required, .references("songs", "id"))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("recommend_playlists_songs").delete()
    }
}
