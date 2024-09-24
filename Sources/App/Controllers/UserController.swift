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
import SendGrid

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
        
        let hashedPassword = try Bcrypt.hash(registerRequest.password)
        
        let verificationToken = UUID().uuidString

        let user = User(
            username: registerRequest.username,
            email: registerRequest.email,
            passwordHash: hashedPassword,
            isVerified: false,
            verificationToken: verificationToken
        )
        
        try await user.save(on: req.db)
        try await sendVerificationEmail(to: user, on: req)
        
        return .created
    }

    func verifyEmail(req: Request) async throws -> HTTPStatus {
        guard let token = req.parameters.get("token") else {
            throw Abort(.badRequest, reason: "Missing verification token")
        }
        
        guard let user = try await User.query(on: req.db)
            .filter(\.$verificationToken == token)
            .first() else {
            throw Abort(.notFound, reason: "Invalid verification token")
        }
        
        user.isVerified = true
        user.verificationToken = nil
        try await user.save(on: req.db)
        
        return .ok
    }

    private func sendVerificationEmail(to user: User, on req: Request) async throws {
        let verificationLink = "http://localhost:8080/api/users/verify/\(user.verificationToken ?? "")"
        
        let email = SendGridEmail(
            personalizations: [
                Personalization(
                    to: [.init(email: user.email)],
                    subject: "Verify Your Email"
                )
            ],
            from: .init(email: "noreply@yourapp.com"), // 발신 이메일
            content: [
                [
                    "type": "text/plain",
                    "value": "Please click the following link to verify your email: \(verificationLink)"
                ],
                [
                    "type": "text/html",
                    "value": "<html><body><h1>Email Verification</h1><p>Please click <a href='\(verificationLink)'>here</a> to verify your email.</p></body></html>"
                ]
            ]
        )
        
        let sendGridClient = req.application.sendgrid.client
        try await sendGridClient.send(email: email)
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
