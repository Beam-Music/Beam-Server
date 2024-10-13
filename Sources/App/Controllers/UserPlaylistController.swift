//
//  UserPlaylist.swift
//  Beam-Music-Server
//
//  Created by freed on 9/26/24.
//

import Vapor
import Fluent
import JWT

struct UserPlaylistController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let jwtProtected = routes.grouped(JWTMiddleware())
        let playlists = jwtProtected.grouped("user-playlists")
        playlists.get(use: index)
        playlists.post(use: create)
        playlists.get(":playlistID", use: get)
        playlists.put(":playlistID", use: update)
        playlists.delete(":playlistID", use: delete)
        playlists.post(":playlistID", "songs", ":songID", use: addSong)
        playlists.delete(":playlistID", "songs", ":songID", use: removeSong)
        playlists.get(":playlistID", "songs", use: getSongs)
    }
    
    func index(req: Request) async throws -> [UserPlaylist] {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == payload.username)
            .first() else {
            throw Abort(.notFound)
        }
        return try await UserPlaylist.query(on: req.db)
            .filter(\.$userID == user.id!)
            .all()
    }
    
    func create(req: Request) async throws -> UserPlaylist {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == payload.username)
            .first() else {
            throw Abort(.notFound)
        }
        var playlist = try req.content.decode(UserPlaylist.self)
        playlist.userID = user.id!
        try await playlist.save(on: req.db)
        return playlist
    }
    
    func get(req: Request) async throws -> UserPlaylist {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == payload.username)
            .first() else {
            throw Abort(.notFound)
        }
        guard let playlistIDString = req.parameters.get("playlistID"),
              let playlistID = UUID(uuidString: playlistIDString),
              let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$userID == user.id!)
            .first() else {
            throw Abort(.notFound)
        }
        return playlist
    }
    
    func update(req: Request) async throws -> UserPlaylist {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == payload.username)
            .first() else {
            throw Abort(.notFound)
        }
        guard let playlistIDString = req.parameters.get("playlistID"),
              let playlistID = UUID(uuidString: playlistIDString),
              let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$userID == user.id!)
            .first() else {
            throw Abort(.notFound)
        }
        let updatedPlaylist = try req.content.decode(UserPlaylist.self)
        playlist.name = updatedPlaylist.name
        try await playlist.save(on: req.db)
        return playlist
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == payload.username)
            .first() else {
            throw Abort(.notFound)
        }
        guard let playlistIDString = req.parameters.get("playlistID"),
              let playlistID = UUID(uuidString: playlistIDString),
              let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$userID == user.id!)
            .first() else {
            throw Abort(.notFound)
        }
        try await playlist.delete(on: req.db)
        return .noContent
    }
    
    func addSong(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == payload.username)
            .first() else {
            throw Abort(.notFound)
        }
        guard let playlistIDString = req.parameters.get("playlistID"),
              let playlistID = UUID(uuidString: playlistIDString),
              let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$userID == user.id!)
            .first(),
              let songIDString = req.parameters.get("songID"),
              let songID = UUID(uuidString: songIDString),
              let song = try await Song.find(songID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await playlist.$songs.attach(song, on: req.db)
        return .created
    }
    
    func removeSong(req: Request) async throws -> HTTPStatus {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == payload.username)
            .first() else {
            throw Abort(.notFound)
        }
        guard let playlistIDString = req.parameters.get("playlistID"),
              let playlistID = UUID(uuidString: playlistIDString),
              let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$userID == user.id!)
            .first(),
              let songIDString = req.parameters.get("songID"),
              let songID = UUID(uuidString: songIDString),
              let song = try await Song.find(songID, on: req.db) else {
            throw Abort(.notFound)
        }
        try await playlist.$songs.detach(song, on: req.db)
        return .noContent
    }
    
    func getSongs(req: Request) async throws -> [SongDTO] {
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        let songs = try await Song.query(on: req.db)
               .join(PlaylistSong.self, on: \Song.$id == \PlaylistSong.$song.$id)
               .filter(PlaylistSong.self, \.$playlist.$id == playlistID)
               .all()
        
        return songs.map { SongDTO(from: $0) }
    }
}
