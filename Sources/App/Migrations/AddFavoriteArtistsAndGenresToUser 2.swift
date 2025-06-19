//
//  AddFavoriteArtistsAndGenresToUser 2.swift
//  Beam-Music-Server
//
//  Created by anonymous on 6/10/25.
//


import Fluent

struct AddFavoriteArtistsAndGenresToUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("favorite_artists", .array(of: .string), .required, .sql(.default("{}")))
            .field("favorite_genres", .array(of: .string), .required, .sql(.default("{}")))
            .update()
    }
    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("favorite_artists")
            .deleteField("favorite_genres")
            .update()
    }
}
