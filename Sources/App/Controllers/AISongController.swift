//
//  AISongController.swift
//  Beam-Music-Server
//
//  Created by freed on 10/25/24.
//

import Vapor
import Fluent

struct AISongController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let aisongs = routes.grouped("aisongs")
        aisongs.get(use: getAllHandler)
        aisongs.get(":songID", use: getHandler)
    }

    func getAllHandler(_ req: Request) async throws -> [AISong] {
        try await AISong.query(on: req.db).all()
    }

    func getHandler(_ req: Request) async throws -> AISong {
        guard let song = try await AISong.find(req.parameters.get("songID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return song
    }
}

