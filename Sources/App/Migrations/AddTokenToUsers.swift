//
//  File.swift
//  
//
//  Created by freed on 9/20/24.
//
import Vapor
import Fluent

struct AddTokenToUsers: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users")
            .field("token", .string)
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users")
            .deleteField("token")
            .update()
    }
}

