//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//

import Fluent

//struct CreateUser: AsyncMigration {
//    func prepare(on database: Database) async throws {
//        try await database.schema("users")
//            .id()
//            .field("email", .string, .required)
//            .unique(on: "email")
//            .field("username", .string, .required)
//            .create()
//    }
//
//    func revert(on database: Database) async throws {
//        try await database.schema("users").delete()
//    }
//}

struct AddPasswordHashToUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users")
            .field("password_hash", .string, .required)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users")
            .deleteField("password_hash")
            .update()
    }
}

struct AddIsVerifiedToUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users")
            .field("is_verified", .bool, .required)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users")
            .deleteField("is_verified")
            .update()
    }
}

