//
//  AddEmailToUsers.swift
//  Beam-Music-Server
//
//  Created by freed on 10/17/24.
//


import Fluent

struct AddEmailToUsers: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("email", .string, .required)
            .unique(on: "email")
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("email")
            .update()
    }
}
