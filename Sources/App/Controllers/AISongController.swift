import Fluent
import Vapor
import Foundation

struct AiSongInput: Content {
    let songId: UUID
    let fileUrl: String
}

struct RegisterAISongRequest: Content {
    let title: String
    let fileName: String
    let genre: String?
    let duration: Int?
    // let artistName: String?
}

struct AISongController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let aiSongs = routes.grouped("api", "ai-songs")
        
        aiSongs.get("playable", use: getPlayableAISongs)
        aiSongs.post("register", use: registerNewAISongHandler)
        aiSongs.get(":aiSongID", use: getHandlerAsync)
    }
    
    func getPlayableAISongs(_ req: Request) async throws -> [PlayableTrackDTO] {
        let aiGeneratedSongs = try await Song.query(on: req.db)
            .filter(\.$isAIGenerated == true)
            .with(\.$artist)
            .all()
        
        guard !aiGeneratedSongs.isEmpty else { return [] }
        
        let songIDs = try aiGeneratedSongs.map { try $0.requireID() }
        let aiSongsData = try await AiSong.query(on: req.db)
            .filter(\.$songId ~~ songIDs) // AiSong.$songId 필요
            .all()
        let aiSongMap = Dictionary(uniqueKeysWithValues: aiSongsData.map { ($0.songId, $0) })
        
        return try aiGeneratedSongs.map { song -> PlayableTrackDTO in
            guard let artist = song.$artist.value else {
                throw Abort(.internalServerError, reason: "Artist not loaded for AI song \(try song.requireID())")
            }
            let correspondingAiSong = aiSongMap[try song.requireID()]
            return try PlayableTrackDTO(song: song, artist: artist, aiSong: correspondingAiSong)
        }
    }

    private func getOrCreateArtist(named name: String, on database: Database) async throws -> Artist.IDValue {
        if let existingArtist = try await Artist.query(on: database)
            .filter(\.$name == name)
            .first() {
            return try existingArtist.requireID()
        } else {
            let newArtist = Artist(name: name, debutYear: 2024)
            try await newArtist.save(on: database)
            print("Created new Artist '\(name)' during AI song registration.")
            return try newArtist.requireID()
        }
    }
    
    
    func registerNewAISongHandler(_ req: Request) async throws -> Song {
        let input = try req.content.decode(RegisterAISongRequest.self)
        let artistName = "AI Composer"
        let artistID = try await getOrCreateArtist(named: artistName, on: req.db)
        
        let newSong = Song(
            title: input.title,
            artistID: artistID,
            genre: input.genre ?? "AI Generated",
            releaseDate: nil,
            duration: input.duration,
            isAIGenerated: true
        )
        try await newSong.save(on: req.db)
        let newSongID = try newSong.requireID()
        print("Registered new Song: '\(input.title)' with ID: \(newSongID)")
        
        let fileUrl = "/ai-songs/\(input.fileName)"
        let aiSong = AiSong(
            songId: newSongID,
            fileUrl: fileUrl
        )
        
        let existingAiSong = try await AiSong.query(on: req.db)
            .filter(\.$songId == newSongID)
            .first()
        if existingAiSong == nil {
            try await aiSong.save(on: req.db)
            print("Created new AiSong record linking to Song ID: \(newSongID)")
        } else {
            print("AiSong record already exists for Song ID: \(newSongID). Skipping AiSong creation.")
            // 필요하다면 기존 AiSong의 fileUrl 업데이트 로직 추가 가능
        }
        
        return newSong
    }
 
    func getAllHandlerAsync(_ req: Request) async throws -> [AiSong] {
        req.logger.info("Fetching AI generated songs from 'AiSong' model...")
        let aiSongs = try await AiSong.query(on: req.db).all()

        return try await withThrowingTaskGroup(of: AiSong.self, returning: [AiSong].self) { group in
            for aiSong in aiSongs {
                group.addTask {
                    return try await aiSong.loadSongDetails(on: req.db)
                }
            }
            var loadedAiSongs: [AiSong] = []
            for try await loadedSong in group {
                loadedAiSongs.append(loadedSong)
            }
            return loadedAiSongs
        }
       
    }
    
    func getHandlerAsync(_ req: Request) async throws -> AiSong {
        guard let id = req.parameters.get("aiSongID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid AI song ID format")
        }
        
        guard let aiSong = try await AiSong.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        
        return try await aiSong.loadSongDetails(on: req.db)
    }
   
    func createHandlerAsync(_ req: Request) async throws -> AiSong {
        let aiSongInput = try req.content.decode(AiSongInput.self)
        
        guard try await Song.find(aiSongInput.songId, on: req.db) != nil else {
            throw Abort(.notFound, reason: "Referenced song not found")
        }
        
        let aiSong = AiSong(
            songId: aiSongInput.songId,
            fileUrl: aiSongInput.fileUrl
            // createdAt은 @Timestamp가 관리
        )
        
        try await aiSong.save(on: req.db)
        return aiSong
    }
    
    func serveAudioFile(_ req: Request) throws -> Response {
        let pathComponents = req.parameters.getCatchall()
        guard !pathComponents.isEmpty else {
            throw Abort(.badRequest, reason: "File path is missing")
        }
        let path = pathComponents.joined(separator: "/")
        
        guard !path.contains("..") else {
            throw Abort(.forbidden, reason: "Invalid file path")
        }
        
        let fileDirectory = DirectoryConfiguration.detect().resourcesDirectory
        let filePath = "\(fileDirectory)Public/ai-songs/\(path)"
        
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw Abort(.notFound, reason: "Audio file not found at path: \(filePath)")
        }
        
        let response = Response(status: .ok)
        if filePath.hasSuffix(".mp3") {
            response.headers.contentType = .mp3
        } else if filePath.hasSuffix(".wav") {
            response.headers.contentType = .wav
        } else if filePath.hasSuffix(".m4a") {
            response.headers.contentType = HTTPMediaType(type: "audio", subType: "mp4")
        } else if filePath.hasSuffix(".aac") {
            response.headers.contentType = HTTPMediaType(type: "audio", subType: "aac")
        } else if filePath.hasSuffix(".ogg") {
            response.headers.contentType = HTTPMediaType(type: "audio", subType: "ogg")
        } else {
            response.headers.contentType = .binary
        }
        
        do {
            response.body = .init(data: try Data(contentsOf: URL(fileURLWithPath: filePath)))
            return response
        } catch {
            throw Abort(.internalServerError, reason: "Failed to read audio file: \(error.localizedDescription)")
        }
    }
}

extension HTTPMediaType {
    static var mp3: HTTPMediaType { HTTPMediaType(type: "audio", subType: "mpeg") }
    static var wav: HTTPMediaType { HTTPMediaType(type: "audio", subType: "wav") }
}
