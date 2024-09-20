//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//
import Vapor

struct SongController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let songs = routes.grouped("songs")
        songs.get(use: index)
        songs.post(use: create)
        songs.get(":songID", use: get)
        songs.put(":songID", use: update)
        songs.delete(":songID", use: delete)
    }

    func index(req: Request) async throws -> [Song] {
        try await Song.query(on: req.db).all()
    }

    func create(req: Request) async throws -> Song {
        let song = try req.content.decode(Song.self)
        try await song.save(on: req.db)
        return song
    }

    func get(req: Request) async throws -> Song {
        guard let song = try await Song.find(req.parameters.get("songID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return song
    }

    func update(req: Request) async throws -> Song {
        guard let song = try await Song.find(req.parameters.get("songID"), on: req.db) else {
            throw Abort(.notFound)
        }
        let updatedSong = try req.content.decode(Song.self)
        song.title = updatedSong.title
        song.genre = updatedSong.genre
        song.releaseDate = updatedSong.releaseDate
        song.duration = updatedSong.duration
        song.artist = updatedSong.artist
        try await song.save(on: req.db)
        return song
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let song = try await Song.find(req.parameters.get("songID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await song.delete(on: req.db)
        return .noContent
    }
}

