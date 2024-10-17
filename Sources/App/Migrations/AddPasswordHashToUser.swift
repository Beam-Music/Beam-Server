//
//  AddPasswordHashToUser.swift
//  Beam-Music-Server
//
//  Created by freed on 10/17/24.
//


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
