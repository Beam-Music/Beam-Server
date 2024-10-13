//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//

import Vapor
import JWT
import Fluent
import Crypto

struct UserPayload: JWTPayload, Authenticatable {
    var username: String
    var exp: ExpirationClaim

    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users")
        users.post("login", use: login)
        let tokenProtected = users.grouped(JWTMiddleware())
        tokenProtected.get(":userID", use: get)
        tokenProtected.put(":userID", use: update)
        tokenProtected.delete(":userID", use: delete)
    }
    

    func get(req: Request) async throws -> User {
        let payload = try req.auth.require(UserPayload.self)

        guard let user = try await User.query(on: req.db)
            .filter(\.$username == payload.username)
            .first() else {
            throw Abort(.notFound)
        }

        return user
    }

    func login(req: Request) async throws -> TokenResponse {
        let loginRequest = try req.content.decode(LoginRequest.self)

        guard let user = try await User.query(on: req.db)
            .filter(\.$username == loginRequest.username)
            .first() else {
            throw Abort(.unauthorized)
        }
        
        let passwordMatches = try Bcrypt.verify(loginRequest.password, created: user.passwordHash)
        guard passwordMatches else {
            throw Abort(.unauthorized)
        }

        let expirationDate = Date().addingTimeInterval(60 * 60 * 24)
        let payload = UserPayload(username: user.username, exp: ExpirationClaim(value: expirationDate))
        let token = try req.jwt.sign(payload)

        return TokenResponse(token: token)
    }

    func update(req: Request) async throws -> User {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        let updatedUser = try req.content.decode(User.self)
        user.username = updatedUser.username
        user.email = updatedUser.email
        try await user.save(on: req.db)
        return user
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await user.delete(on: req.db)
        return .noContent
    }
}

struct LoginRequest: Content {
    let username: String
    let password: String
}

struct TokenResponse: Content {
    let token: String
}
