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
    var exp: ExpirationClaim

    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users")
        users.post("register", use: register)
        users.post("verify", use: verifyEmail)
        users.post("login", use: login)
        
        let tokenProtected = users.grouped(JWTMiddleware())
        tokenProtected.get(":userID", use: get)
        tokenProtected.put(":userID", use: update)
        tokenProtected.delete(":userID", use: delete)
    }

    // MARK: - Registration
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
    func verifyEmail(req: Request) async throws -> HTTPStatus {
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
        
        return .ok
    }

    // MARK: - Login
    func login(req: Request) async throws -> TokenResponse {
        let loginRequest = try req.content.decode(LoginRequest.self)

        guard let user = try await User.query(on: req.db)
            .filter(\.$username == loginRequest.username)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        let passwordMatches = try Bcrypt.verify(loginRequest.password, created: user.passwordHash)
        guard passwordMatches else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }

        let expirationDate = Date().addingTimeInterval(60 * 60 * 24)
        let payload = UserPayload(username: user.username, exp: ExpirationClaim(value: expirationDate))
        let token = try req.jwt.sign(payload)

        return TokenResponse(token: token)
    }

    // MARK: - Get User by ID
    func get(req: Request) async throws -> User {
        let payload = try req.auth.require(UserPayload.self)
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == payload.username)
            .first() else {
            throw Abort(.notFound)
        }

        return user
    }

    // MARK: - Update User by ID
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

    // MARK: - Delete User by ID
    func delete(req: Request) async throws -> HTTPStatus {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
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
