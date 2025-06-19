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
        users.post("send-verification-code", use: sendVerificationCode)
        
        // 인증 없이 유저 프로필 조회 가능
        users.get(":userID", "profile", use: getProfile)
        
        tokenProtected.group(":userID") { user in
            user.get(use: get)
            user.put(use: update)
            user.delete(use: delete)
            user.group("taste") { taste in
                taste.put(use: updateTaste)
            }
        }
    }

    // MARK: - Registration
    @Sendable
    func register(req: Request) async throws -> UserDTO {
        let username = try req.content.get(String.self, at: "username")
        let email = try req.content.get(String.self, at: "email")
        let password = try req.content.get(String.self, at: "password")
        let profileImage: File? = try? req.content.get(File.self, at: "profileImage")

        var profileImageURL: String? = nil
        if let image = profileImage {
            let directory = req.application.directory.publicDirectory + "profile_images"
            if !FileManager.default.fileExists(atPath: directory) {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            }
            let filename = "\(UUID().uuidString)-\(image.filename)"
            let savePath = directory + "/" + filename
            let buffer = image.data
            try await req.fileio.writeFile(buffer, at: savePath)
            profileImageURL = "/profile_images/" + filename
        }

        if let existingUser = try await User.query(on: req.db).filter(\.$email == email).first() {
            // 기존 verification row 모두 삭제
            try await Verification.query(on: req.db)
                .filter(\.$email == email)
                .delete()
            let verificationCode = String(Int.random(in: 100000...999999))
            let expiresAt = Date().addingTimeInterval(600)
            let newVerification = Verification(email: email, code: verificationCode, expiresAt: expiresAt)
            try await newVerification.save(on: req.db)
            let emailController = EmailController()
            try await emailController.sendVerificationEmail(req: req, user: existingUser, verificationCode: verificationCode)
            return UserDTO(from: existingUser)
        }

        let hashedPassword = try Bcrypt.hash(password)
        let user = User(username: username, email: email, passwordHash: hashedPassword, profileImageURL: profileImageURL)
        try await user.save(on: req.db)
        // 기존 verification row 모두 삭제
        try await Verification.query(on: req.db)
            .filter(\.$email == email)
            .delete()
        let verificationCode = String(Int.random(in: 100000...999999))
        let expiresAt = Date().addingTimeInterval(600)
        let verification = Verification(email: email, code: verificationCode, expiresAt: expiresAt)
        try await verification.save(on: req.db)
        let emailController = EmailController()
        try await emailController.sendVerificationEmail(req: req, user: user, verificationCode: verificationCode)
        return UserDTO(from: user)
    }

    // MARK: - Verify Email
    @Sendable
    func verifyEmail(req: Request) async throws -> VerifyResponse {
        let verifyRequest = try req.content.decode(VerifyRequest.self)
        // 인증코드 검증
        guard let verification = try await Verification.query(on: req.db)
            .filter(\.$email == verifyRequest.email)
            .filter(\.$code == verifyRequest.code)
            .first() else {
                let resp = VerifyResponse(success: false, token: nil, reason: "인증번호가 일치하지 않습니다.")
                req.logger.info("verifyEmail response: \(resp)")
                return resp
        }
        if verification.expiresAt < Date() {
            let resp = VerifyResponse(success: false, token: nil, reason: "인증번호가 만료되었습니다.")
            req.logger.info("verifyEmail response: \(resp)")
            return resp
        }
        var token: String? = nil
        if let user = try await User.query(on: req.db)
            .filter(\.$email == verifyRequest.email)
            .first() {
            user.isVerified = true
            try await user.save(on: req.db)
            let expirationDate = Date().addingTimeInterval(60 * 60 * 24)
            let payload = UserPayload(
                username: user.username,
                userId: try user.requireID(),
                exp: ExpirationClaim(value: expirationDate)
            )
            token = try req.jwt.sign(payload)
        }
        let resp = VerifyResponse(success: true, token: token, reason: nil)
        req.logger.info("verifyEmail response: \(resp)")
        return resp
    }

    // MARK: - Login
    @Sendable
    func login(req: Request) async throws -> TokenResponse {
        let loginRequest = try req.content.decode(LoginRequest.self)

        let user = try await User.query(on: req.db)
            .filter(\.$email == loginRequest.email)
            .first()
            
        guard let user = user else {
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        guard user.isVerified else {
            throw Abort(.unauthorized, reason: "Please verify your email before logging in")
        }
        
        // 비밀번호 검증 직전 로그 추가
        print("[LOGIN DEBUG] email: \(loginRequest.email), 입력 비밀번호: \(loginRequest.password), DB 해시: \(user.passwordHash)")
        
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
        // 연관 데이터 먼저 삭제
        try await Verification.query(on: req.db)
            .filter(\Verification.$email == user.email)
            .delete()
        try await UserPlaylist.query(on: req.db)
            .filter(\UserPlaylist.$user.$id == userID)
            .delete()
        // 필요하다면 다른 연관 테이블도 추가
        try await user.delete(on: req.db)
        return .noContent
    }

    @Sendable
    func updateTaste(req: Request) async throws -> UserDTO {
        let payload = try req.auth.require(UserPayload.self)
        guard let userID = req.parameters.get("userID", as: UUID.self),
              userID == payload.userId else {
            throw Abort(.forbidden, reason: "You can only update your own account's taste")
        }
        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.notFound)
        }
        let update = try req.content.decode(UpdateTasteRequest.self)
        user.favoriteArtists = update.favoriteArtists
        user.favoriteGenres = update.favoriteGenres
        try await user.save(on: req.db)
        return UserDTO(from: user)
    }

    // MARK: - Get User Profile (Public)
    @Sendable
    func getProfile(req: Request) async throws -> UserDTO {
        guard let userID = req.parameters.get("userID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        guard let user = try await User.find(userID, on: req.db) else {
            throw Abort(.notFound, reason: "User not found")
        }
        return UserDTO(from: user)
    }

    // MARK: - Send Verification Code (이메일 인증번호만 발송)
    @Sendable
    func sendVerificationCode(req: Request) async throws -> HTTPStatus {
        struct EmailRequest: Content { let email: String }
        let emailRequest = try req.content.decode(EmailRequest.self)
        let email = emailRequest.email
        // 기존 verification row 모두 삭제
        try await Verification.query(on: req.db)
            .filter(\.$email == email)
            .delete()
        // 인증코드 생성 및 저장
        let verificationCode = String(Int.random(in: 100000...999999))
        let expiresAt = Date().addingTimeInterval(600)
        let newVerification = Verification(email: email, code: verificationCode, expiresAt: expiresAt)
        try await newVerification.save(on: req.db)
        // 이메일 발송
        let fakeUser = User(username: email, email: email, passwordHash: "", profileImageURL: nil)
        let emailController = EmailController()
        try await emailController.sendVerificationEmail(req: req, user: fakeUser, verificationCode: verificationCode)
        return .ok
    }
}

// MARK: - Data Transfer Objects
struct LoginRequest: Content {
    let email: String
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

struct UpdateTasteRequest: Content {
    let favoriteArtists: [String]
    let favoriteGenres: [String]
}

struct SuccessResponse: Content {
    let success: Bool
}

struct VerifyResponse: Content, CustomStringConvertible {
    let success: Bool
    let token: String?
    let reason: String?
    var description: String {
        "{success: \(success), token: \(token ?? "nil"), reason: \(reason ?? "nil")}"
    }
}
