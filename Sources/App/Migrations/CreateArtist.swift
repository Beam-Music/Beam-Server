//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//
import Fluent

struct CreateArtist: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("artists")
            .id()
            .field("name", .string, .required)
            .field("debut_year", .int)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("artists").delete()
    }
}
