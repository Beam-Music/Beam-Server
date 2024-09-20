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
        // Extract and verify the JWT token
        let token = try req.jwt.verify(as: UserPayload.self)
        
        // Store the authenticated user info (e.g., username) in the request's auth system
        req.auth.login(token)
        
        return try await next.respond(to: req)
    }
}
