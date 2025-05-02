import Vapor
import Fluent

struct RecommendPlaylistController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let jwtProtected = routes.grouped(JWTMiddleware())
        let playlists = jwtProtected.grouped("recommend-playlists")
        
        playlists.get(use: index)
        playlists.post(use: create)
        playlists.get(":playlistID", use: get)
        playlists.put(":playlistID", use: update)
        playlists.group(":playlistID") { playlist in
            playlist.get("songs", use: getSongs)
        }
    }

    
    @Sendable
    func index(req: Request) async throws -> [PlaylistSummaryDTO] {
        let playlists = try await RecommendPlaylist.query(on: req.db).all()
        return playlists.map { playlist in
            PlaylistSummaryDTO(id: playlist.id, name: playlist.name, description: playlist.description)
        }
    }

    @Sendable
    func getSongs(req: Request) async throws -> [PlayableTrackDTO] {
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid playlist ID format.")
        }

        let playlistQuery = RecommendPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .with(\.$songs) { songQuery in
                songQuery.with(\.$artist)
            }

        let optionalPlaylist = try await playlistQuery.first()

        guard let playlist = optionalPlaylist else {
            throw Abort(.notFound, reason: "Playlist with ID \(playlistID) not found.")
        }

        let songs = playlist.songs
        guard !songs.isEmpty else {
            return []
        }

        let songIDs = try songs.map { try $0.requireID() }

        let aiSongs = try await AiSong.query(on: req.db)
            .filter(\.$song.$id ~~ songIDs)
            .all()

        
        let aiSongMap = Dictionary(uniqueKeysWithValues: aiSongs.map { ($0.$song.id, $0) })

        
        return try songs.map { song -> PlayableTrackDTO in
            // Artist was eagerly loaded, so it should be available.
            guard let artist = song.$artist.value else {
                // This should ideally not happen if eager loading succeeded.
                throw Abort(.internalServerError, reason: "Artist data unexpectedly missing for song \(try song.requireID()).")
            }
            // Find the corresponding AiSong (if it exists) from the map.
            let correspondingAiSong = aiSongMap[try song.requireID()]

            // Create the DTO. Ensure PlayableTrackDTO initializer is correct.
            // Check if PlayableTrackDTO init throws or if any access here causes generic errors.
            return try PlayableTrackDTO(song: song, artist: artist, aiSong: correspondingAiSong)
        }
    }

    // POST /recommend-playlists
    // Creates a new recommendation playlist.
    @Sendable
    func create(req: Request) async throws -> RecommendPlaylist {
        let payload = try req.auth.require(UserPayload.self)
        let playlistData = try req.content.decode(PlaylistCreateDTO.self)
        
        let playlist = RecommendPlaylist(
            name: playlistData.name,
            description: playlistData.description ?? "",
            userID: payload.userId
        )
        
        try await playlist.save(on: req.db)
        return playlist
    }

    // GET /recommend-playlists/:playlistID
    // Retrieves a specific recommendation playlist by its ID.
    @Sendable
    func get(req: Request) async throws -> RecommendPlaylist {
        // Get playlist ID from parameters.
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
             throw Abort(.badRequest, reason: "Invalid playlist ID format.")
         }
        // Find the playlist by ID.
        guard let playlist = try await RecommendPlaylist.find(playlistID, on: req.db) else {
            throw Abort(.notFound, reason: "Playlist with ID \(playlistID) not found.")
        }
        return playlist
    }

    // PUT /api/recommend-playlists/:playlistID
    // Updates a specific recommendation playlist by its ID.
    @Sendable
    func update(req: Request) async throws -> RecommendPlaylist {
        // Get playlist ID from parameters
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid playlist ID format.")
        }
        
        // Find the existing playlist
        guard let playlist = try await RecommendPlaylist.find(playlistID, on: req.db) else {
            throw Abort(.notFound, reason: "Playlist with ID \(playlistID) not found.")
        }
        
        // Get the authenticated user
        let payload = try req.auth.require(UserPayload.self)
        
        // Verify ownership
        let playlistUser = try await playlist.$user.get(on: req.db)
        guard playlistUser.id == payload.userId else {
            throw Abort(.forbidden, reason: "You can only update your own playlists")
        }
        
        // Decode the update data
        let updateData = try req.content.decode(PlaylistUpdateDTO.self)
        
        // Update the playlist
        playlist.name = updateData.name
        playlist.description = updateData.description ?? ""
        
        // Save changes
        try await playlist.save(on: req.db)
        return playlist
    }
}

// Add these DTOs for create and update requests
struct PlaylistCreateDTO: Content {
    let name: String
    let description: String?
}

struct PlaylistUpdateDTO: Content {
    let name: String
    let description: String?
}
