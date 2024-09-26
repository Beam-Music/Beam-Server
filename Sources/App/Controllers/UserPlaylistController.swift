//
//  UserPlaylist.swift
//  Beam-Music-Server
//
//  Created by freed on 9/26/24.
//

import Vapor
import Fluent

struct UserPlaylistController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let playlists = routes.grouped("user-playlists")
        playlists.get(use: index)
        playlists.post(use: create)
        playlists.get(":playlistID", use: get)
        playlists.put(":playlistID", use: update)
        playlists.delete(":playlistID", use: delete)
        playlists.post(":playlistID", "songs", ":songID", use: addSong)
        playlists.delete(":playlistID", "songs", ":songID", use: removeSong)
    }
    
    func index(req: Request) async throws -> [UserPlaylist] {
        try await UserPlaylist.query(on: req.db).all()
    }
    
    func create(req: Request) async throws -> UserPlaylist {
        let playlist = try req.content.decode(UserPlaylist.self)
        try await playlist.save(on: req.db)
        return playlist
    }
    
    func get(req: Request) async throws -> UserPlaylist {
        guard let playlist = try await UserPlaylist.find(req.parameters.get("playlistID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return playlist
    }
    
    func update(req: Request) async throws -> UserPlaylist {
        guard let playlist = try await UserPlaylist.find(req.parameters.get("playlistID"), on: req.db) else {
            throw Abort(.notFound)
        }
        let updatedPlaylist = try req.content.decode(UserPlaylist.self)
        playlist.name = updatedPlaylist.name
        try await playlist.save(on: req.db)
        return playlist
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        guard let playlist = try await UserPlaylist.find(req.parameters.get("playlistID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await playlist.delete(on: req.db)
        return .noContent
    }
    
    func addSong(req: Request) async throws -> HTTPStatus {
        guard let playlist = try await UserPlaylist.find(req.parameters.get("playlistID"), on: req.db),
              let song = try await Song.find(req.parameters.get("songID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await playlist.$songs.attach(song, on: req.db)
        return .created
    }
    
    func removeSong(req: Request) async throws -> HTTPStatus {
        guard let playlist = try await UserPlaylist.find(req.parameters.get("playlistID"), on: req.db),
              let song = try await Song.find(req.parameters.get("songID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await playlist.$songs.detach(song, on: req.db)
        return .noContent
    }
}
