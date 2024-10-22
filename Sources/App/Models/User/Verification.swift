//
//  Verification.swift
//  Beam-Music-Server
//
//  Created by freed on 10/15/24.
//

import Fluent
import Vapor

final class Verification: Model, Content, @unchecked Sendable {
    static let schema = "verifications"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "email")
    var email: String
    
    @Field(key: "code")
    var code: String
    
    @Field(key: "expires_at")
    var expiresAt: Date
    
    init() { }
    
    init(email: String, code: String, expiresAt: Date) {
        self.email = email
        self.code = code
        self.expiresAt = expiresAt
    }
}
