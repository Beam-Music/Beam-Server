import Fluent
import Vapor
import Foundation

struct AiSongInput: Content {
    let songId: UUID
    let fileUrl: String
    // Include other required fields if this DTO is used for direct creation
    // let title: String
    // let duration: Int
    // let isAiGenerated: Bool
    // let genre: String?
    // let releaseDate: Date?
}


struct RegisterAISongRequest: Content {
    let title: String
    let fileName: String
    let genre: String?
    let duration: Int?
}

struct AISongController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let aiSongs = routes.grouped("api", "ai-songs")
        
        aiSongs.get("playable", use: getPlayableAISongs)
        aiSongs.post("register", use: registerNewAISongHandler)
        aiSongs.get(":aiSongID", use: getHandlerAsync)
        aiSongs.get("next-track", use: getNextTrack)
        // aiSongs.post(use: createHandlerAsync)
    }
    
    func getPlayableAISongs(_ req: Request) async throws -> [PlayableTrackDTO] {
        let aiGeneratedSongs = try await Song.query(on: req.db)
            .filter(\.$isAIGenerated == true)
            .with(\.$artist)
            .all()
        
        guard !aiGeneratedSongs.isEmpty else { return [] }
        
        let songIDs = try aiGeneratedSongs.map { try $0.requireID() }
        
        let aiSongsData = try await AiSong.query(on: req.db)
            .filter(\.$song.$id ~~ songIDs)
            .all()
        
        let aiSongMap = Dictionary(uniqueKeysWithValues: aiSongsData.map { ($0.$song.id, $0) })
        
        
        return try aiGeneratedSongs.map { (song: Song) -> PlayableTrackDTO in
            guard let artist: Artist = song.$artist.value else {
                throw Abort(.internalServerError, reason: "Artist not loaded for AI song \(try song.requireID())")
            }
            let correspondingAiSong: AiSong? = aiSongMap[try song.requireID()]
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
        
        let fileUrl = "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3"
        
        let aiSong = AiSong(
            title: newSong.title,
            genre: newSong.genre,
            releaseDate: newSong.releaseDate,
            duration: newSong.duration ?? 0,
            isAiGenerated: true,
            fileUrl: fileUrl,
            songId: newSongID
        )
        
        let existingAiSong = try await AiSong.query(on: req.db)
            .filter(\.$song.$id == newSongID)
            .first()
        
        if existingAiSong == nil {
            try await aiSong.save(on: req.db)
        } else {
            print("AiSong record already exists for Song ID: \(newSongID). Skipping AiSong creation.")
        }
        
        return newSong
    }
    
    func getHandlerAsync(_ req: Request) async throws -> AiSong {
        guard let aiSongID = req.parameters.get("aiSongID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid AI song ID format")
        }
        
        guard let aiSong = try await AiSong.find(aiSongID, on: req.db) else {
            throw Abort(.notFound, reason: "AiSong with ID \(aiSongID) not found.")
        }
        
        return try await aiSong.loadSongDetails(on: req.db)
    }
    
    func getNextTrack(_ req: Request) async throws -> PlayableTrackDTO {
        let currentTrackID = try req.query.get(UUID.self, at: "currentTrackID")
        let isAIMusicEnabled = try req.query.get(Bool.self, at: "isAIMusicEnabled")
        
        print("Getting next track for currentTrackID: \(currentTrackID), isAIMusicEnabled: \(isAIMusicEnabled)")
        
        // Get current track
        guard let currentTrack = try await Song.find(currentTrackID, on: req.db) else {
            throw Abort(.notFound, reason: "Current track not found")
        }
        
        print("Current track: \(currentTrack.title), isAIGenerated: \(String(describing: currentTrack.isAIGenerated))")
        
        // Get all songs from the same playlist
        let playlistQuery = UserPlaylist.query(on: req.db)
            .filter(\.$songs.$id == currentTrackID)
            .with(\.$songs) { songBuilder in
                songBuilder.with(\.$artist)
            }
        
        guard let playlist = try await playlistQuery.first() else {
            throw Abort(.notFound, reason: "Playlist not found")
        }
        
        let songs = playlist.songs
        guard !songs.isEmpty else {
            throw Abort(.notFound, reason: "No songs in playlist")
        }
        
        print("Total songs in playlist: \(songs.count)")
        
        // Find current track index
        guard let currentIndex = songs.firstIndex(where: { try $0.requireID() == currentTrackID }) else {
            throw Abort(.notFound, reason: "Current track not found in playlist")
        }
        
        print("Current track index: \(currentIndex)")
        
        // Get next track based on AI music preference
        let nextTrack: Song
        if isAIMusicEnabled {
            // Find next AI track
            let remainingSongs = Array(songs[(currentIndex + 1)...] + songs[..<currentIndex])
            print("Looking for next AI track in \(remainingSongs.count) remaining songs")
            if let nextAITrack = remainingSongs.first(where: { $0.isAIGenerated == true }) {
                nextTrack = nextAITrack
                print("Found next AI track: \(nextAITrack.title)")
            } else {
                // If no AI track found, start from beginning
                nextTrack = songs[0]
                print("No AI track found, starting from beginning: \(songs[0].title)")
            }
        } else {
            // Find next non-AI track (explicitly check for false)
            let remainingSongs = Array(songs[(currentIndex + 1)...] + songs[..<currentIndex])
            print("Looking for next non-AI track in \(remainingSongs.count) remaining songs")
            if let nextNonAITrack = remainingSongs.first(where: { $0.isAIGenerated == false }) {
                nextTrack = nextNonAITrack
                print("Found next non-AI track: \(nextNonAITrack.title)")
            } else {
                // If no non-AI track found, start from beginning
                nextTrack = songs[0]
                print("No non-AI track found, starting from beginning: \(songs[0].title)")
            }
        }
        
        // Get artist and AI song details
        guard let artist = nextTrack.$artist.value else {
            throw Abort(.internalServerError, reason: "Artist not found for next track")
        }
        
        let aiSong = try await AiSong.query(on: req.db)
            .filter(\.$song.$id == try nextTrack.requireID())
            .first()
        
        print("Returning next track: \(nextTrack.title), isAIGenerated: \(String(describing: nextTrack.isAIGenerated))")
        
        return try PlayableTrackDTO(song: nextTrack, artist: artist, aiSong: aiSong)
    }
    
    func createHandlerAsync(_ req: Request) async throws -> AiSong {
        let input = try req.content.decode(AiSongInput.self)
        
        guard let referencedSong = try await Song.find(input.songId, on: req.db) else {
            throw Abort(.notFound, reason: "Referenced song with ID \(input.songId) not found")
        }
        
        let aiSong = AiSong(
            title: referencedSong.title,
            genre: referencedSong.genre,
            releaseDate: referencedSong.releaseDate,
            duration: referencedSong.duration ?? 0,
            isAiGenerated: true,
            fileUrl: input.fileUrl,
            songId: input.songId
        )
        
        try await aiSong.save(on: req.db)
        return aiSong
    }
}

// Helper HTTPMediaType definitions
extension HTTPMediaType {
    static var mp3: HTTPMediaType { HTTPMediaType(type: "audio", subType: "mpeg") }
    static var wav: HTTPMediaType { HTTPMediaType(type: "audio", subType: "wav") }
}

