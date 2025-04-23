//
//  AddEmailAndPasswordToUser.swift
//  Beam-Music-Server
//
//  Created by anonymous on 4/23/25.
//

import Fluent

struct AddEmailAndPasswordToUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("email", .string, .required)
            .field("password_hash", .string, .required)
            .unique(on: "email")
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("email")
            .deleteField("password_hash")
            .update()
    }
}
