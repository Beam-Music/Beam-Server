//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//
import Vapor

struct ListeningHistoryController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let history = routes.grouped("listening-history")
        history.get(use: index)
        history.post(use: create)
        history.get(":historyID", use: get)
        history.delete(":historyID", use: delete)
    }

    func index(req: Request) async throws -> [ListeningHistory] {
        try await ListeningHistory.query(on: req.db).all()
    }

    func create(req: Request) async throws -> ListeningHistory {
        let history = try req.content.decode(ListeningHistory.self)
        try await history.save(on: req.db)
        return history
    }

    func get(req: Request) async throws -> ListeningHistory {
        guard let history = try await ListeningHistory.find(req.parameters.get("historyID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return history
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let history = try await ListeningHistory.find(req.parameters.get("historyID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await history.delete(on: req.db)
        return .noContent
    }
}

