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
        // Decode the playlist data from the request body.
        let playlistData = try req.content.decode(RecommendPlaylist.self) // Assumes request body matches RecommendPlaylist structure
        // Save the new playlist to the database.
        try await playlistData.save(on: req.db)
        return playlistData
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
}
