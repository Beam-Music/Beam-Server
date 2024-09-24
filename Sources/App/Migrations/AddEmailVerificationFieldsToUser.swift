//
//  File.swift
//  
//
//  Created by freed on 9/24/24.
//

import Fluent

struct AddEmailVerificationFieldsToUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .field("is_verified", .bool, .required, .sql(.default(false)))
            .field("verification_token", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users")
            .deleteField("is_verified")
            .deleteField("verification_token")
            .update()
    }
}

