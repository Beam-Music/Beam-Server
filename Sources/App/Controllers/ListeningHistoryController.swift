//
//  File.swift
//
//
//  Created by freed on 9/13/24.
//
import Vapor
import Fluent

struct ListeningHistoryController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let jwtProtected = routes.grouped(JWTMiddleware())
        let history = jwtProtected.grouped("api", "listening-history")

        history.get(use: index)
        history.post(use: create)
        history.get(":historyID", use: get)
        history.delete(":historyID", use: delete)
    }

    @Sendable
    func index(req: Request) async throws -> [ListeningHistory] {
        let payload = try req.auth.require(UserPayload.self)
        return try await ListeningHistory.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .all()
    }

    @Sendable
    func create(req: Request) async throws -> ListeningHistory {
        let payload = try req.auth.require(UserPayload.self)
        let history = try req.content.decode(ListeningHistory.self)
        history.$user.id = payload.userId
        try await history.save(on: req.db)
        return history
    }

    @Sendable
    func get(req: Request) async throws -> ListeningHistory {
        let payload = try req.auth.require(UserPayload.self)
        guard let history = try await ListeningHistory.find(req.parameters.get("historyID"), on: req.db) else {
            throw Abort(.notFound)
        }
        guard history.$user.id == payload.userId else {
            throw Abort(.forbidden, reason: "You can only access your own listening history")
        }
        return history
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let history = try await ListeningHistory.find(req.parameters.get("historyID"), on: req.db) else {
            throw Abort(.notFound)
        }
        guard history.$user.id == payload.userId else {
            throw Abort(.forbidden, reason: "You can only delete your own listening history")
        }
        try await history.delete(on: req.db)
        return .noContent
    }
}
