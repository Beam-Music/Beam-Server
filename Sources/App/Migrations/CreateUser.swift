//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//

import Fluent

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

struct CreateUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users")
            .id()
            .field("username", .string, .required)
            .field("password", .string, .required)
            .field("is_verified", .bool, .required, .sql(.default(false)))
            .create()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users").delete()
    }
}
