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
        print("🚀 Setting up AISongController routes...")
        let aiSongs = routes.grouped("api", "ai-songs")
        print("📡 Created ai-songs route group")
        
        aiSongs.get("playable") { req -> [PlayableTrackDTO] in
            print("🎯 Received request for /api/ai-songs/playable")
            do {
                print("🎵 Starting getPlayableAISongs...")
                let result = try await self.getPlayableAISongs(req)
                print("✅ Successfully returned \(result.count) playable tracks")
                return result
            } catch {
                print("❌ Error in playable endpoint: \(error)")
                throw error
            }
        }
        
        aiSongs.post("register", use: registerNewAISongHandler)
        aiSongs.get(":aiSongID", use: getHandlerAsync)
        aiSongs.get("next-track", use: getNextTrack)
        // aiSongs.post(use: createHandlerAsync)
        print("✅ AISongController routes setup completed")
    }
    
    @Sendable
    func getPlayableAISongs(_ req: Request) async throws -> [PlayableTrackDTO] {
        print("🎵 [getPlayableAISongs] Function started")
        
        do {
            // 1. Query songs with AI flag
            print("🔍 [getPlayableAISongs] Querying songs with isAIGenerated = true")
            let aiGeneratedSongs = try await Song.query(on: req.db)
                .filter(\.$isAIGenerated == true)
                .with(\.$artist)
                .all()
            
            print("📊 [getPlayableAISongs] Found \(aiGeneratedSongs.count) AI songs")
            
            if aiGeneratedSongs.isEmpty {
                print("ℹ️ [getPlayableAISongs] No AI songs found in database")
                return []
            }
            
            // 2. Get song IDs and fetch AI song data
            let songIDs = try aiGeneratedSongs.map { song -> UUID in
                let id = try song.requireID()
                print("🎵 [getPlayableAISongs] Processing song: \(song.title) (ID: \(id))")
                return id
            }
            
            // 3. Fetch AI song data
            print("🔍 [getPlayableAISongs] Fetching AI song data")
            let aiSongsData = try await AiSong.query(on: req.db)
                .filter(\.$song.$id ~~ songIDs)
                .all()
            
            print("📊 [getPlayableAISongs] Found \(aiSongsData.count) AI song records")
            
            // 4. Create lookup map
            let aiSongMap = Dictionary(uniqueKeysWithValues: aiSongsData.map { ($0.$song.id, $0) })
            
            // 5. Create DTOs
            var playableTracks: [PlayableTrackDTO] = []
            for song in aiGeneratedSongs {
                do {
                    let songId = try song.requireID()
                    print("\n🎵 [getPlayableAISongs] Creating DTO for: \(song.title)")
                    
                    guard let artist = song.$artist.value else {
                        print("⚠️ [getPlayableAISongs] Artist not loaded for: \(song.title)")
                        continue
                    }
                    
                    let aiSong = aiSongMap[songId]
                    print("   Artist: \(artist.name)")
                    print("   AI Song Data: \(aiSong != nil ? "Found" : "Not Found")")
                    if let aiSong = aiSong {
                        print("   File URL: \(aiSong.fileUrl)")
                    }
                    
                    let dto = try PlayableTrackDTO(song: song, artist: artist, aiSong: aiSong)
                    playableTracks.append(dto)
                    print("✅ [getPlayableAISongs] Successfully created DTO for: \(song.title)")
                } catch {
                    print("❌ [getPlayableAISongs] Error creating DTO for song: \(song.title)")
                    print("   Error: \(error)")
                    continue
                }
            }
            
            print("✅ [getPlayableAISongs] Successfully created \(playableTracks.count) DTOs")
            return playableTracks
            
        } catch {
            print("❌ [getPlayableAISongs] Error: \(error)")
            throw error
        }
    }
    
    @Sendable
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
    
    @Sendable
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
    
    @Sendable
    func getHandlerAsync(_ req: Request) async throws -> AiSong {
        guard let aiSongID = req.parameters.get("aiSongID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid AI song ID format")
        }
        
        guard let aiSong = try await AiSong.find(aiSongID, on: req.db) else {
            throw Abort(.notFound, reason: "AiSong with ID \(aiSongID) not found.")
        }
        
        return try await aiSong.loadSongDetails(on: req.db)
    }
    
    @Sendable
    func getNextTrack(_ req: Request) async throws -> PlayableTrackDTO {
        let currentTrackID = try req.query.get(UUID.self, at: "currentTrackID")
        let isAIMusicEnabled = try req.query.get(Bool.self, at: "isAIMusicEnabled")
        
        print("Getting next track for currentTrackID: \(currentTrackID), isAIMusicEnabled: \(isAIMusicEnabled)")
        
        // Get current track with artist
        guard let currentTrack = try await Song.query(on: req.db)
            .with(\.$artist)
            .filter(\.$id == currentTrackID)
            .first() else {
            throw Abort(.notFound, reason: "Current track not found")
        }
        
        print("Current track: \(currentTrack.title), isAIGenerated: \(String(describing: currentTrack.isAIGenerated))")
        
        // Get all songs from the same playlist with artists preloaded
        let playlistQuery = UserPlaylist.query(on: req.db)
            .join(PlaylistSong.self, on: \UserPlaylist.$id == \PlaylistSong.$playlist.$id)
            .filter(PlaylistSong.self, \.$song.$id == currentTrackID)
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
        print("AI songs count: \(songs.filter { $0.isAIGenerated ?? false }.count)")
        print("Non-AI songs count: \(songs.filter { !($0.isAIGenerated ?? false) }.count)")
        
        // Find current track index
        guard let currentIndex = try songs.firstIndex(where: { try $0.requireID() == currentTrackID }) else {
            throw Abort(.notFound, reason: "Current track not found in playlist")
        }
        
        print("Current track index: \(currentIndex)")
        
        // Get next track based on AI music preference
        let nextTrack: Song
        if isAIMusicEnabled {
            // Get all AI tracks in the playlist
            let aiTracks = songs.filter { $0.isAIGenerated == true }
            guard !aiTracks.isEmpty else {
                // If no AI tracks, just play the next song in the playlist
                nextTrack = songs[(currentIndex + 1) % songs.count]
                print("No AI tracks found, playing next song: \(nextTrack.title)")
                return try await createPlayableTrackDTO(from: nextTrack, on: req.db)
            }
            
            // Find the next AI track after the current position
            let nextAITrackIndex = aiTracks.firstIndex { track in
                guard let trackIndex = try? songs.firstIndex(where: { try $0.requireID() == track.requireID() }) else {
                    return false
                }
                return trackIndex > currentIndex
            }
            
            if let nextAITrackIndex = nextAITrackIndex {
                nextTrack = aiTracks[nextAITrackIndex]
                print("Found next AI track: \(nextTrack.title)")
            } else {
                if currentTrack.isAIGenerated == true {
                    nextTrack = aiTracks[0]
                    print("Starting from first AI track: \(nextTrack.title)")
                } else {
                    if let firstAITrack = aiTracks.first {
                        nextTrack = firstAITrack
                        print("Found first AI track: \(firstAITrack.title)")
                    } else {
                        nextTrack = songs[(currentIndex + 1) % songs.count]
                        print("No AI tracks found, playing next song: \(nextTrack.title)")
                    }
                }
            }
        } else {
            let remainingSongs = Array(songs[(currentIndex + 1)...] + songs[..<currentIndex])
            print("Looking for next non-AI track in \(remainingSongs.count) remaining songs")
            
            if let nextNonAITrack = remainingSongs.first(where: { $0.isAIGenerated == false }) {
                nextTrack = nextNonAITrack
                print("Found next non-AI track: \(nextNonAITrack.title)")
            } else {
                // If no non-AI tracks found, start from the beginning
                nextTrack = songs[0]
                print("No non-AI tracks found, starting from beginning: \(songs[0].title)")
            }
        }
        
        return try await createPlayableTrackDTO(from: nextTrack, on: req.db)
    }
    
    private func createPlayableTrackDTO(from song: Song, on db: Database) async throws -> PlayableTrackDTO {
        let songID = try song.requireID()
        
        // Load the artist relationship if not already loaded
        if song.$artist.value == nil {
            try await song.$artist.load(on: db)
        }
        
        guard let artist = song.$artist.value else {
            throw Abort(.internalServerError, reason: "Artist not found for song")
        }
        
        // For AI songs, ensure we have the AI song data
        if song.isAIGenerated == true {
            guard let aiSong = try await AiSong.query(on: db)
                .filter(\.$song.$id == songID)
                .first() else {
                throw Abort(.internalServerError, reason: "AI song data not found for song: \(song.title)")
            }
            return try PlayableTrackDTO(song: song, artist: artist, aiSong: aiSong)
        }
        
        return try PlayableTrackDTO(song: song, artist: artist, aiSong: nil)
    }
    
    @Sendable
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

