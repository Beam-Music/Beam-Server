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

    func index(req: Request) async throws -> [PlaylistSummaryDTO] {
        let playlists = try await RecommendPlaylist.query(on: req.db).all()
        return playlists.map { PlaylistSummaryDTO(id: $0.id, name: $0.name, description: $0.description) }
    }

    func getSongs(req: Request) async throws -> [PlayableTrackDTO] {
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
            throw Abort(.badRequest)
        }

        guard let playlist = try await RecommendPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .with(\.$songs)
            .first() else {
            throw Abort(.notFound)
        }

        let songs = playlist.songs
        guard !songs.isEmpty else { return [] }

        try await songs.loadArtists(on: req.db)

        let songIDs = try songs.map { try $0.requireID() }
        let aiSongs = try await AiSong.query(on: req.db)
            .filter(\.$songId ~~ songIDs)
            .all()
        let aiSongMap = Dictionary(uniqueKeysWithValues: aiSongs.map { ($0.songId, $0) })

        return try songs.map { song -> PlayableTrackDTO in
            guard let artist = song.$artist.value else {
                throw Abort(.internalServerError, reason: "Artist not loaded for song \(try song.requireID())")
            }
            let correspondingAiSong = aiSongMap[try song.requireID()]
            return try PlayableTrackDTO(song: song, artist: artist, aiSong: correspondingAiSong)
        }
    }

    func create(req: Request) async throws -> RecommendPlaylist {
        let playlist = try req.content.decode(RecommendPlaylist.self)
        try await playlist.save(on: req.db)
        return playlist
    }

    func get(req: Request) async throws -> RecommendPlaylist {
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self),
              let playlist = try await RecommendPlaylist.find(playlistID, on: req.db) else {
            throw Abort(.notFound)
        }
        return playlist
    }
}
