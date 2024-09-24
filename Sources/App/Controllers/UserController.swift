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

    // This method ensures that the JWT payload is valid (expiration is not passed)
    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users")
        users.post("login", use: login)
        users.post("register", use: register)
        let tokenProtected = users.grouped(JWTMiddleware())
        tokenProtected.get(":userID", use: get)
        tokenProtected.put(":userID", use: update)
        tokenProtected.delete(":userID", use: delete)
    }
    
    func register(req: Request) async throws -> HTTPStatus {
        try RegisterRequest.validate(content: req)
        let registerRequest = try req.content.decode(RegisterRequest.self)
        
        // Check if user already exists
        if let _ = try await User.query(on: req.db)
            .filter(\.$username == registerRequest.username)
            .first() {
            throw Abort(.conflict, reason: "Username already exists")
        }
        
        if let _ = try await User.query(on: req.db)
            .filter(\.$email == registerRequest.email)
            .first() {
            throw Abort(.conflict, reason: "Email already exists")
        }
        
        // Hash the password
        let hashedPassword = try Bcrypt.hash(registerRequest.password)
        
        // Create new user
        let user = User(
            username: registerRequest.username,
            email: registerRequest.email,
            passwordHash: hashedPassword
        )
        
        // Save user to database
        try await user.save(on: req.db)
        
        return .created
    }


    func get(req: Request) async throws -> User {
        // 인증된 사용자 정보를 JWT에서 추출
        let payload = try req.auth.require(UserPayload.self)

        // JWT에서 추출한 사용자 이름으로 DB에서 사용자를 찾음
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == payload.username)
            .first() else {
            throw Abort(.notFound)
        }

        return user
    }

    func login(req: Request) async throws -> TokenResponse {
        let loginRequest = try req.content.decode(LoginRequest.self)

        // Authenticate user (ensure this logic works for you)
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == loginRequest.username)
            .first() else {
            throw Abort(.unauthorized)
        }
        
        let passwordMatches = try Bcrypt.verify(loginRequest.password, created: user.passwordHash)
        guard passwordMatches else {
            throw Abort(.unauthorized)  // 비밀번호가 틀릴 때
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

struct RegisterRequest: Content {
    let username: String
    let email: String
    let password: String
}

extension RegisterRequest: Validatable {
    static func validations(_ validations: inout Validations) {
        validations.add("username", as: String.self, is: !.empty && .count(3...))
        validations.add("email", as: String.self, is: .email)
        validations.add("password", as: String.self, is: .count(8...))
    }
}

struct LoginRequest: Content {
    let username: String
    let password: String
}

struct TokenResponse: Content {
    let token: String
}
