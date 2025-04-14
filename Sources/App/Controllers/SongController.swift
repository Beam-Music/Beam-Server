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
        let updatedSongData = try req.content.decode(Song.self)

        // 기존 song 객체의 필드를 업데이트
        song.title = updatedSongData.title
        song.genre = updatedSongData.genre
        song.releaseDate = updatedSongData.releaseDate
        song.duration = updatedSongData.duration

        // --- 오류 수정된 부분 ---
        // 'artist'는 String 필드이므로 직접 값을 할당합니다.
        song.artist = updatedSongData.artist
        // --- 수정 완료 ---

        // isAIGenerated 필드도 업데이트가 필요하다면 추가:
        // song.isAIGenerated = updatedSongData.isAIGenerated

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

