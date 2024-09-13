//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//

import Vapor

struct ArtistController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let artists = routes.grouped("artists")
        artists.get(use: index)
        artists.post(use: create)
        artists.get(":artistID", use: get)
        artists.put(":artistID", use: update)
        artists.delete(":artistID", use: delete)
    }

    func index(req: Request) async throws -> [Artist] {
        try await Artist.query(on: req.db).all()
    }

    func create(req: Request) async throws -> Artist {
        let artist = try req.content.decode(Artist.self)
        try await artist.save(on: req.db)
        return artist
    }

    func get(req: Request) async throws -> Artist {
        guard let artist = try await Artist.find(req.parameters.get("artistID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return artist
    }

    func update(req: Request) async throws -> Artist {
        guard let artist = try await Artist.find(req.parameters.get("artistID"), on: req.db) else {
            throw Abort(.notFound)
        }
        let updatedArtist = try req.content.decode(Artist.self)
        artist.name = updatedArtist.name
        artist.debutYear = updatedArtist.debutYear
        try await artist.save(on: req.db)
        return artist
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let artist = try await Artist.find(req.parameters.get("artistID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await artist.delete(on: req.db)
        return .noContent
    }
}
