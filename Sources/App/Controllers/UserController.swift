//
//  File.swift
//
//
//  Created by freed on 9/13/24.
//

import Vapor
import JWT
import Fluent
import SendGrid
import Crypto

struct UserPayload: JWTPayload, Authenticatable {
    var username: String
    var userId: UUID
    var exp: ExpirationClaim

    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("api", "users")
        let tokenProtected = users.grouped(JWTMiddleware())
        
        users.post("register", use: register)
        users.post("verify", use: verifyEmail)
        users.post("login", use: login)
        
        tokenProtected.get(":userID", use: get)
        tokenProtected.put(":userID", use: update)
        tokenProtected.delete(":userID", use: delete)
    }

    // MARK: - Registration
    @Sendable
    func register(req: Request) async throws -> HTTPStatus {
        let registerRequest = try req.content.decode(RegisterRequest.self)
        
        if let existingUser = try await User.query(on: req.db).filter(\.$email == registerRequest.email).first() {
            let verificationCode = String(Int.random(in: 100000...999999))
            let expiresAt = Date().addingTimeInterval(600)
            
            if let existingVerification = try await Verification.query(on: req.db)
                .filter(\.$email == registerRequest.email)
                .first() {
                existingVerification.code = verificationCode
                existingVerification.expiresAt = expiresAt
                try await existingVerification.save(on: req.db)
            } else {
                let newVerification = Verification(email: registerRequest.email, code: verificationCode, expiresAt: expiresAt)
                try await newVerification.save(on: req.db)
            }
            
            let emailController = EmailController()
            try await emailController.sendVerificationEmail(req: req, user: existingUser, verificationCode: verificationCode)
            
            return .ok
        }
        
        let hashedPassword = try Bcrypt.hash(registerRequest.password)
        let user = User(username: registerRequest.username, email: registerRequest.email, passwordHash: hashedPassword)
        try await user.save(on: req.db)
        
        let verificationCode = String(Int.random(in: 100000...999999))
        let expiresAt = Date().addingTimeInterval(600)
        
        let verification = Verification(email: registerRequest.email, code: verificationCode, expiresAt: expiresAt)
        try await verification.save(on: req.db)
        
        let emailController = EmailController()

        try await emailController.sendVerificationEmail(req: req, user: user, verificationCode: verificationCode)
        return .created
    }

    // MARK: - Verify Email
    @Sendable
    func verifyEmail(req: Request) async throws -> TokenResponse {
        let verifyRequest = try req.content.decode(VerifyRequest.self)
        
        guard let verification = try await Verification.query(on: req.db)
            .filter(\.$email == verifyRequest.email)
            .filter(\.$code == verifyRequest.code)
            .first() else {
                throw Abort(.notFound, reason: "Invalid verification code or email")
        }
        
        if verification.expiresAt < Date() {
            throw Abort(.unauthorized, reason: "Verification code expired")
        }
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$email == verifyRequest.email)
            .first() else {
                throw Abort(.notFound, reason: "User not found")
        }
        user.isVerified = true
        try await user.save(on: req.db)
        
        // Generate and return JWT token
        let expirationDate = Date().addingTimeInterval(60 * 60 * 24) // 24 hours
        let payload = UserPayload(
            username: user.username,
            userId: try user.requireID(),
            exp: ExpirationClaim(value: expirationDate)
        )
        let token = try req.jwt.sign(payload)
        
        return TokenResponse(token: token)
    }

    // MARK: - Login
    @Sendable
    func login(req: Request) async throws -> TokenResponse {
        let loginRequest = try req.content.decode(LoginRequest.self)

        let user = try await User.query(on: req.db)
            .group(.or) { builder in
                builder.filter(\.$username == loginRequest.username)
                builder.filter(\.$email == loginRequest.username)
            }
            .first()
            
        guard let user = user else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        guard user.isVerified else {
            throw Abort(.unauthorized, reason: "Please verify your email before logging in")
        }
        
        let passwordMatches = try await req.password.async.verify(loginRequest.password, created: user.passwordHash)
        guard passwordMatches else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        let expirationDate = Date().addingTimeInterval(60 * 60 * 24) // 24 hours
        let payload = UserPayload(
            username: user.username,
            userId: try user.requireID(),
            exp: ExpirationClaim(value: expirationDate)
        )
        
        let token = try req.jwt.sign(payload)
        return TokenResponse(token: token)
    }

    // MARK: - Get User by ID
    @Sendable
    func get(req: Request) async throws -> User {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.find(payload.userId, on: req.db) else {
            throw Abort(.notFound)
        }
        return user
    }

    // MARK: - Update User by ID
    @Sendable
    func update(req: Request) async throws -> User {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = req.parameters.get("userID", as: UUID.self),
              userID == payload.userId else {
            throw Abort(.forbidden, reason: "You can only update your own account")
        }
        
        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.notFound)
        }
        let updatedUser = try req.content.decode(User.self)
        user.username = updatedUser.username
        user.email = updatedUser.email
        try await user.save(on: req.db)
        return user
    }

    // MARK: - Delete User by ID
    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = req.parameters.get("userID", as: UUID.self),
              userID == payload.userId else {
            throw Abort(.forbidden, reason: "You can only delete your own account")
        }
        
        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await user.delete(on: req.db)
        return .noContent
    }
}

// MARK: - Data Transfer Objects
struct LoginRequest: Content {
    let username: String
    let password: String
}

struct TokenResponse: Content {
    let token: String
}

struct RegisterRequest: Content {
    let username: String
    let email: String
    let password: String
}

struct VerifyRequest: Content {
    let email: String
    let code: String
}
