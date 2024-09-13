//
//  File.swift
//  
//
//  Created by freed on 9/12/24.
//

import Fluent
import Vapor

final class User: Model, Content {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "email")
    var email: String

    @Field(key: "password")
    var password: String

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() { }

    init(id: UUID? = nil, username: String, email: String, password: String) {
        self.id = id
        self.username = username
        self.email = email
        self.password = password
    }
}

//struct CreateUser: Migration {
//    func prepare(on database: Database) -> EventLoopFuture<Void> {
//        database.schema("users")
//            .id()
//            .field("username", .string, .required)
//            .field("email", .string, .required)
//            .field("password", .string, .required)
//            .field("created_at", .datetime)
//            .field("updated_at", .datetime)
//            .unique(on: "email")
//            .create()
//    }
//
//    func revert(on database: Database) -> EventLoopFuture<Void> {
//        database.schema("users").delete()
//    }
//}

