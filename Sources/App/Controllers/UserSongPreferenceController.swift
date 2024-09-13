//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//
import Vapor

struct UserSongPreferenceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let preferences = routes.grouped("user-song-preferences")
        preferences.get(use: index)
        preferences.post(use: create)
        preferences.get(":preferenceID", use: get)
        preferences.put(":preferenceID", use: update)
        preferences.delete(":preferenceID", use: delete)
    }

    func index(req: Request) async throws -> [UserSongPreference] {
        try await UserSongPreference.query(on: req.db).all()
    }

    func create(req: Request) async throws -> UserSongPreference {
        let preference = try req.content.decode(UserSongPreference.self)
        try await preference.save(on: req.db)
        return preference
    }

    func get(req: Request) async throws -> UserSongPreference {
        guard let preference = try await UserSongPreference.find(req.parameters.get("preferenceID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return preference
    }

    func update(req: Request) async throws -> UserSongPreference {
        guard let preference = try await UserSongPreference.find(req.parameters.get("preferenceID"), on: req.db) else {
            throw Abort(.notFound)
        }
        let updatedPreference = try req.content.decode(UserSongPreference.self)
        preference.rating = updatedPreference.rating
        try await preference.save(on: req.db)
        return preference
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let preference = try await UserSongPreference.find(req.parameters.get("preferenceID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await preference.delete(on: req.db)
        return .noContent
    }
}

