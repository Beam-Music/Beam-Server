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

//    @Field(key: "password_hash")
//    var passwordHash: String
//
//    @Field(key: "is_verified")
//    var isVerified: Bool
//
//    @Timestamp(key: "created_at", on: .create)
//    var createdAt: Date?
//
//    @Timestamp(key: "updated_at", on: .update)
//    var updatedAt: Date?

    init() {}
    
    init(id: UUID? = nil, username: String, email: String, passwordHash: String, isVerified: Bool = false) {
        self.id = id
        self.username = username
        self.email = email
//        self.passwordHash = passwordHash
//        self.isVerified = isVerified
    }
}
