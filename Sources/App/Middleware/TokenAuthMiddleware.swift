//
//  File.swift
//  
//
//  Created by freed on 9/20/24.
//

import Vapor
import Fluent

struct TokenAuthMiddleware: AsyncMiddleware {
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        guard let token = request.headers.bearerAuthorization?.token else {
            throw Abort(.unauthorized, reason: "Missing authentication token")
        }

        guard let user = try await User.query(on: request.db)
            .filter(\User.$token, .equal, token)
            .first() else {
            throw Abort(.unauthorized, reason: "Invalid token")
        }

        request.auth.login(user)
        return try await next.respond(to: request)
    }
}


