//
//  File.swift
//
//
//  Created by freed on 9/13/24.
//
import Vapor
import Fluent

struct UserSongPreferenceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let jwtProtected = routes.grouped(JWTMiddleware())
        let preferences = jwtProtected.grouped("api", "user-song-preferences")

        preferences.get(use: index)
        preferences.post(use: create)
        preferences.get(":preferenceID", use: get)
        preferences.put(":preferenceID", use: update)
        preferences.delete(":preferenceID", use: delete)
    }

    @Sendable
    func index(req: Request) async throws -> [UserSongPreference] {
        let payload = try req.auth.require(UserPayload.self)
        return try await UserSongPreference.query(on: req.db)
            .filter(\.$user.$id == payload.userId)
            .all()
    }

    @Sendable
    func create(req: Request) async throws -> UserSongPreference {
        let payload = try req.auth.require(UserPayload.self)
        let preference = try req.content.decode(UserSongPreference.self)
        preference.$user.id = payload.userId
        try await preference.save(on: req.db)
        return preference
    }

    @Sendable
    func get(req: Request) async throws -> UserSongPreference {
        let payload = try req.auth.require(UserPayload.self)
        guard let preference = try await UserSongPreference.find(req.parameters.get("preferenceID"), on: req.db) else {
            throw Abort(.notFound)
        }
        guard preference.$user.id == payload.userId else {
            throw Abort(.forbidden, reason: "You can only access your own preferences")
        }
        return preference
    }

    @Sendable
    func update(req: Request) async throws -> UserSongPreference {
        let payload = try req.auth.require(UserPayload.self)
        guard let preference = try await UserSongPreference.find(req.parameters.get("preferenceID"), on: req.db) else {
            throw Abort(.notFound)
        }
        guard preference.$user.id == payload.userId else {
            throw Abort(.forbidden, reason: "You can only update your own preferences")
        }
        let updatedPreference = try req.content.decode(UserSongPreference.self)
        preference.rating = updatedPreference.rating
        try await preference.save(on: req.db)
        return preference
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let preference = try await UserSongPreference.find(req.parameters.get("preferenceID"), on: req.db) else {
            throw Abort(.notFound)
        }
        guard preference.$user.id == payload.userId else {
            throw Abort(.forbidden, reason: "You can only delete your own preferences")
        }
        try await preference.delete(on: req.db)
        return .noContent
    }
}
