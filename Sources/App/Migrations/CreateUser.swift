//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//

import Fluent

struct CreateUser: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("users")
            .id()
//            .field("username", .string, .required)
            .field("email", .string, .required)
//            .field("password_hash", .string, .required)
//            .field("created_at", .datetime)
//            .field("updated_at", .datetime)
            .unique(on: "email")
            .field("username", .string, .required)  // username 필드 추가
            .field("password", .string, .required)  // password 필드 추가
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("users").delete()
    }
}
