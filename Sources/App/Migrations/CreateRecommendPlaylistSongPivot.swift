//
//  CreateRecommendPlaylistSongPivot.swift
//  Beam-Music-Server
//
//  Created by anonymous on 4/23/25.
//

import Fluent

struct CreateRecommendPlaylistSongPivot: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("recommend_playlists_songs")
            .id()
            .field("playlist_id", .uuid, .required,
                   .references("playlist_recommendation", "id", onDelete: .cascade))
            .field("song_id", .uuid, .required,
                   .references("songs", "id", onDelete: .cascade))
            .unique(on: "playlist_id", "song_id")
            .create()
    }
    
    func revert(on database: Database) async throws {
        try await database.schema("recommend_playlists_songs").delete()
    }
}
