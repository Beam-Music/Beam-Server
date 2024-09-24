//
//  File.swift
//  
//
//  Created by freed on 9/12/24.
//

import Fluent
import Vapor

final class User: Model, Content, Authenticatable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "email")
    var email: String
    
    @OptionalField(key: "token")
    var token: String?
    
    @Field(key: "password_hash")
    var passwordHash: String
    
    @Field(key: "is_verified")
    var isVerified: Bool
    
    @OptionalField(key: "verification_token")
    var verificationToken: String?
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}
    
    init(id: UUID? = nil, username: String, email: String, passwordHash: String, isVerified: Bool = false, verificationToken: String? = nil) {
        self.id = id
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.isVerified = isVerified
        self.verificationToken = verificationToken
    }
}
