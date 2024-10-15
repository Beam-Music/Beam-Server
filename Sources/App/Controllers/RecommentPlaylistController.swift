//
//  RecommentPlaylistController.swift
//  Beam-Music-Server
//
//  Created by freed on 10/13/24.
//

import Vapor
import Fluent

struct RecommendPlaylistController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let playlists = routes.grouped("recommend-playlists")
        playlists.get(use: index)
        playlists.post(use: create)
        playlists.get(":playlistID", use: get)
        playlists.group(":playlistID") { playlist in
            playlist.get("songs", use: getSongs)
        }
    }
    
    func index(req: Request) async throws -> [RecommendPlaylist] {
        return try await RecommendPlaylist.query(on: req.db).all()
    }
    
    func create(req: Request) async throws -> RecommendPlaylist {
        var playlist = try req.content.decode(RecommendPlaylist.self)
        try await playlist.save(on: req.db)
        return playlist
    }
    
    func get(req: Request) async throws -> RecommendPlaylist {
        guard let playlistIDString = req.parameters.get("playlistID"),
              let playlistID = UUID(uuidString: playlistIDString),
              let playlist = try await RecommendPlaylist.find(playlistID, on: req.db) else {
            throw Abort(.notFound)
        }
        return playlist
    }
    
    func getSongs(req: Request) async throws -> [SongDTO] {
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let playlist = try await RecommendPlaylist
            .query(on: req.db)
            .filter(\.$id == playlistID)
            .with(\.$songs)
            .first()
        else {
            throw Abort(.notFound)
        }
        let songs = playlist.songs
        
        return songs.map { SongDTO(from: $0) }
    }

}
