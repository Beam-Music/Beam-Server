//
//  CreateVerification.swift
//  Beam-Music-Server
//
//  Created by freed on 10/15/24.
//
import Fluent

struct CreateVerification: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("verifications")
            .id()
            .field("email", .string, .required)
            .field("code", .string, .required)
            .field("expires_at", .datetime, .required)
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("verifications").delete()
    }
}
