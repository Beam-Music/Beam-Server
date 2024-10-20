//
//  RemovePasswordFromUsers.swift
//  Beam-Music-Server
//
//  Created by freed on 10/18/24.
//
import Fluent

struct RemovePasswordFromUsers: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users")
            .deleteField("password")
            .update()
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        database.schema("users")
            .field("password", .string, .required)
            .update()
    }
}
