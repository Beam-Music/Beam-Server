//
//  File.swift
//  
//
//  Created by freed on 9/20/24.
//

import Vapor

struct AuthenticatedUserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        routes.get("profile", use: getProfile)
        routes.put("profile", use: updateProfile)
        // 기타 인증이 필요한 사용자 관련 라우트...
    }

    func getProfile(req: Request) async throws -> User {
        try req.auth.require(User.self)
    }

    func updateProfile(req: Request) async throws -> User {
        let user = try req.auth.require(User.self)
        let updateData = try req.content.decode(UserUpdateData.self)
        user.username = updateData.name
        // 다른 필드 업데이트...
        try await user.save(on: req.db)
        return user
    }
}

struct UserUpdateData: Content {
    let name: String
    // 다른 업데이트 가능한 필드들...
}

