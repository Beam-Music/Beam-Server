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
    var type: String // "access" or "refresh"

    func verify(using signer: JWTSigner) throws {
        try exp.verifyNotExpired()
    }
}

struct RefreshTokenPayload: JWTPayload {
    var userId: UUID
    var exp: ExpirationClaim
    var type: String // "refresh"
    
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
        users.post("refresh", use: refreshToken) // 새로운 엔드포인트
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
            // 파일 크기 제한 (5MB)
            let maxSize = 5 * 1024 * 1024
            guard image.data.readableBytes <= maxSize else {
                throw Abort(.badRequest, reason: "Profile image must be under 5MB")
            }
            // 허용 확장자 검증
            let allowedExtensions = ["jpg", "jpeg", "png", "webp", "heic"]
            let ext = image.filename.lowercased().split(separator: ".").last.map(String.init) ?? ""
            guard allowedExtensions.contains(ext) else {
                throw Abort(.badRequest, reason: "Only image files are allowed (jpg, png, webp, heic)")
            }
            let directory = req.application.directory.publicDirectory + "profile_images"
            if !FileManager.default.fileExists(atPath: directory) {
                try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            }
            let safeFilename = "\(UUID().uuidString).\(ext)"
            let savePath = directory + "/" + safeFilename
            let buffer = image.data
            try await req.fileio.writeFile(buffer, at: savePath)
            profileImageURL = "/profile_images/" + safeFilename
        }

        if let _ = try await User.query(on: req.db).filter(\.$email == email).first() {
            throw Abort(.conflict, reason: "This email is already registered.")
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
        // 토큰 발급
        let accessTokenExpiration = Date().addingTimeInterval(60 * 60 * 24 * 7)
        let accessPayload = UserPayload(
            username: user.username,
            userId: try user.requireID(),
            exp: ExpirationClaim(value: accessTokenExpiration),
            type: "access"
        )
        
        let refreshTokenExpiration = Date().addingTimeInterval(60 * 60 * 24 * 30)
        let refreshPayload = RefreshTokenPayload(
            userId: try user.requireID(),
            exp: ExpirationClaim(value: refreshTokenExpiration),
            type: "refresh"
        )
        
        let accessToken = try req.jwt.sign(accessPayload)
        let refreshToken = try req.jwt.sign(refreshPayload)
        
        return UserDTO(
            from: user,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: 60 * 60 * 24 * 7,
            tokenType: "Bearer"
        )
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
                let resp = VerifyResponse(
                    success: false,
                    accessToken: nil,
                    refreshToken: nil,
                    expiresIn: nil,
                    tokenType: nil,
                    reason: "인증번호가 일치하지 않습니다."
                )
                req.logger.info("verifyEmail response: \(resp)")
                return resp
        }
        if verification.expiresAt < Date() {
            let resp = VerifyResponse(
                success: false,
                accessToken: nil,
                refreshToken: nil,
                expiresIn: nil,
                tokenType: nil,
                reason: "인증번호가 만료되었습니다."
            )
            req.logger.info("verifyEmail response: \(resp)")
            return resp
        }
        var accessToken: String? = nil
        var refreshToken: String? = nil
        var expiresIn: Int? = nil
        var tokenType: String? = nil
        
        if let user = try await User.query(on: req.db)
            .filter(\.$email == verifyRequest.email)
            .first() {
            user.isVerified = true
            try await user.save(on: req.db)
            
            // 새로운 토큰 시스템 적용
            let accessTokenExpiration = Date().addingTimeInterval(60 * 60 * 24 * 7) // 7일
            let accessPayload = UserPayload(
                username: user.username,
                userId: try user.requireID(),
                exp: ExpirationClaim(value: accessTokenExpiration),
                type: "access"
            )
            
            let refreshTokenExpiration = Date().addingTimeInterval(60 * 60 * 24 * 30) // 30일
            let refreshPayload = RefreshTokenPayload(
                userId: try user.requireID(),
                exp: ExpirationClaim(value: refreshTokenExpiration),
                type: "refresh"
            )
            
            accessToken = try req.jwt.sign(accessPayload)
            refreshToken = try req.jwt.sign(refreshPayload)
            expiresIn = 60 * 60 * 24 * 7
            tokenType = "Bearer"
        }
        
        let resp = VerifyResponse(
            success: true,
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            tokenType: tokenType,
            reason: nil
        )
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
            req.logger.warning("[LOGIN FAILURE] User not found for email: \(loginRequest.email)")
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        guard user.isVerified else {
            throw Abort(.unauthorized, reason: "Please verify your email before logging in")
        }
        
        let passwordMatches = try await req.password.async.verify(loginRequest.password, created: user.passwordHash)
        guard passwordMatches else {
            req.logger.warning("[LOGIN FAILURE] Password mismatch for user: \(user.email)")
            throw Abort(.unauthorized, reason: "Invalid credentials")
        }
        
        // Access Token: 7일 (더 긴 세션 유지)
        let accessTokenExpiration = Date().addingTimeInterval(60 * 60 * 24 * 7)
        let accessPayload = UserPayload(
            username: user.username,
            userId: try user.requireID(),
            exp: ExpirationClaim(value: accessTokenExpiration),
            type: "access"
        )
        
        // Refresh Token: 30일 (자동 로그인 유지)
        let refreshTokenExpiration = Date().addingTimeInterval(60 * 60 * 24 * 30)
        let refreshPayload = RefreshTokenPayload(
            userId: try user.requireID(),
            exp: ExpirationClaim(value: refreshTokenExpiration),
            type: "refresh"
        )
        
        let accessToken = try req.jwt.sign(accessPayload)
        let refreshToken = try req.jwt.sign(refreshPayload)
        
        return TokenResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: 60 * 60 * 24 * 7, // 7일을 초 단위로
            tokenType: "Bearer"
        )
    }

    // MARK: - Refresh Token
    @Sendable
    func refreshToken(req: Request) async throws -> TokenResponse {
        let refreshRequest = try req.content.decode(RefreshTokenRequest.self)
        
        // Refresh Token 검증
        let refreshPayload = try req.jwt.verify(refreshRequest.refreshToken, as: RefreshTokenPayload.self)
        
        // Refresh Token 타입 확인
        guard refreshPayload.type == "refresh" else {
            throw Abort(.unauthorized, reason: "Invalid token type")
        }
        
        // 사용자 존재 확인
        guard let user = try await User.find(refreshPayload.userId, on: req.db) else {
            throw Abort(.unauthorized, reason: "User not found")
        }
        
        // 새로운 Access Token 생성 (7일)
        let accessTokenExpiration = Date().addingTimeInterval(60 * 60 * 24 * 7)
        let accessPayload = UserPayload(
            username: user.username,
            userId: try user.requireID(),
            exp: ExpirationClaim(value: accessTokenExpiration),
            type: "access"
        )
        
        // 새로운 Refresh Token 생성 (30일)
        let refreshTokenExpiration = Date().addingTimeInterval(60 * 60 * 24 * 30)
        let newRefreshPayload = RefreshTokenPayload(
            userId: try user.requireID(),
            exp: ExpirationClaim(value: refreshTokenExpiration),
            type: "refresh"
        )
        
        let accessToken = try req.jwt.sign(accessPayload)
        let refreshToken = try req.jwt.sign(newRefreshPayload)
        
        return TokenResponse(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: 60 * 60 * 24 * 7,
            tokenType: "Bearer"
        )
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
        try await ListeningHistory.query(on: req.db)
            .filter(\ListeningHistory.$user.$id == userID)
            .delete()
        try await UserSongPreference.query(on: req.db)
            .filter(\UserSongPreference.$user.$id == userID)
            .delete()
        try await AIPreference.query(on: req.db)
            .filter(\AIPreference.$userId == userID)
            .delete()
        // RecommendPlaylist의 pivot 데이터는 CASCADE로 처리됨
        try await RecommendPlaylist.query(on: req.db)
            .filter(\RecommendPlaylist.$user.$id == userID)
            .delete()
        try await UserPlaylist.query(on: req.db)
            .filter(\UserPlaylist.$user.$id == userID)
            .delete()
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
        return UserDTO(
            from: user,
            accessToken: nil,
            refreshToken: nil,
            expiresIn: nil,
            tokenType: nil
        )
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
        return UserDTO(
            from: user,
            accessToken: nil,
            refreshToken: nil,
            expiresIn: nil,
            tokenType: nil
        )
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

struct RefreshTokenRequest: Content {
    let refreshToken: String
}

struct TokenResponse: Content {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int // seconds
    let tokenType: String
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
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    let reason: String?
    
    // Backward compatibility
    var token: String? { accessToken }
    
    var description: String {
        "{success: \(success), accessToken: \(accessToken ?? "nil"), refreshToken: \(refreshToken ?? "nil"), expiresIn: \(expiresIn ?? 0), reason: \(reason ?? "nil")}"
    }
}
