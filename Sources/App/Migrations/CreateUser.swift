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
