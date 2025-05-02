//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//
import Vapor

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
        try await ListeningHistory.query(on: req.db).all()
    }

    @Sendable
    func create(req: Request) async throws -> ListeningHistory {
        let history = try req.content.decode(ListeningHistory.self)
        try await history.save(on: req.db)
        return history
    }

    @Sendable
    func get(req: Request) async throws -> ListeningHistory {
        guard let history = try await ListeningHistory.find(req.parameters.get("historyID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return history
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        guard let history = try await ListeningHistory.find(req.parameters.get("historyID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await history.delete(on: req.db)
        return .noContent
    }
}

