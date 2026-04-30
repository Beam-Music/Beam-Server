//
//  File.swift
//  
//
//  Created by freed on 9/19/24.
//

import Vapor
import JWT

struct JWTMiddleware: AsyncMiddleware {
    func respond(to req: Request, chainingTo next: AsyncResponder) async throws -> Response {
        let token = try req.jwt.verify(as: UserPayload.self)

        guard token.type == "access" else {
            throw Abort(.unauthorized, reason: "Invalid token type. Access token required.")
        }

        req.auth.login(token)
        return try await next.respond(to: req)
    }
}
