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

