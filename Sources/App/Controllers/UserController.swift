//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//
import Vapor

struct UserController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let users = routes.grouped("users")
        users.post(use: create)
        users.get(":userID", use: get)
        users.put(":userID", use: update)
        users.delete(":userID", use: delete)
    }

    func create(req: Request) async throws -> User {
        let user = try req.content.decode(User.self)
        try await user.save(on: req.db)
        return user
    }

    func get(req: Request) async throws -> User {
        guard let user = try await User.find(req.parameters.get("userID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return user
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
