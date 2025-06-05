import Vapor
import Fluent

struct HitSongController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let hitSongs = routes.grouped("api", "hit-songs")
        hitSongs.get(use: index)
        hitSongs.get(":songID", use: get)
    }
    
    @Sendable
    func index(req: Request) async throws -> [PlayableTrackDTO] {
        // Get all songs that are marked as hits
        let songs = try await Song.query(on: req.db)
            .with(\.$artist)
            .all()
            
        // Get song IDs for AI song lookup
        let songIDs = try songs.map { try $0.requireID() }
        
        // Load AI songs for these songs
        let aiSongs = try await AiSong.query(on: req.db)
            .filter(\.$song.$id ~~ songIDs)
            .all()
            
        let aiSongMap = Dictionary(uniqueKeysWithValues: aiSongs.map { ($0.$song.id, $0) })
        
        // Create DTOs for each song
        var result: [PlayableTrackDTO] = []
        for song in songs {
            guard let artist = song.$artist.value else {
                throw Abort(.internalServerError, reason: "Artist not found for song \(try song.requireID())")
            }
            
            let correspondingAiSong = aiSongMap[try song.requireID()]
            let dto = try PlayableTrackDTO(song: song, artist: artist, aiSong: correspondingAiSong)
            result.append(dto)
        }
        
        return result
    }
    
    @Sendable
    func get(req: Request) async throws -> PlayableTrackDTO {
        guard let songID = req.parameters.get("songID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid song ID format")
        }
        
        guard let song = try await Song.query(on: req.db)
            .with(\.$artist)
            .filter(\.$id == songID)
            .first() else {
            throw Abort(.notFound, reason: "Song not found")
        }
        
        guard let artist = song.$artist.value else {
            throw Abort(.internalServerError, reason: "Artist not found for song")
        }
        
        let aiSong = try await AiSong.query(on: req.db)
            .filter(\.$song.$id == songID)
            .first()
            
        return try PlayableTrackDTO(song: song, artist: artist, aiSong: aiSong)
    }
} 