import Vapor
import Fluent
import JWT

struct UserPlaylistController: RouteCollection {

    func boot(routes: RoutesBuilder) throws {
        let jwtProtected = routes.grouped(JWTMiddleware())
        let playlists = jwtProtected.grouped("user-playlists")

        playlists.get(use: index)
        playlists.post(use: create)
        playlists.get(":playlistID", use: get)
        playlists.put(":playlistID", use: update)
        playlists.delete(":playlistID", use: delete)

        playlists.post(":playlistID", "songs", ":songID", use: addSong)
        playlists.delete(":playlistID", "songs", ":songID", use: removeSong)
        playlists.get(":playlistID", "songs", use: getSongs)
        playlists.post(":playlistID", "songs", use: addSongByBody)
    }

    private func getUserFromPayload(req: Request) async throws -> User {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.find(payload.userId, on: req.db) else {
            throw Abort(.unauthorized, reason: "User not found for provided token payload.")
        }
        return user
    }

    @Sendable
    func index(req: Request) async throws -> [PlaylistSummaryDTO] {
        let user = try await self.getUserFromPayload(req: req)
        let userID = try user.requireID()
        let playlists = try await UserPlaylist.query(on: req.db)
            .filter(\.$user.$id == userID)
            .all()
        return playlists.map { PlaylistSummaryDTO(id: $0.id, name: $0.name) }
    }

    @Sendable
    func create(req: Request) async throws -> UserPlaylist {
        let user = try await self.getUserFromPayload(req: req)
        let userID = try user.requireID()
        let createData = try req.content.decode(CreateUserPlaylistData.self)
        let playlist = UserPlaylist(name: createData.name, userID: userID)
        try await playlist.save(on: req.db)
        return playlist
    }

    @Sendable
    func get(req: Request) async throws -> UserPlaylist {
        let user = try await self.getUserFromPayload(req: req)
        let userID = try user.requireID()
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid playlist ID format.")
        }
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == userID)
            .first() else {
            throw Abort(.notFound, reason: "Playlist not found or access denied.")
        }
        return playlist
    }

    @Sendable
    func update(req: Request) async throws -> UserPlaylist {
        let user = try await self.getUserFromPayload(req: req)
        let userID = try user.requireID()
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid playlist ID format.")
        }
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == userID)
            .first() else {
            throw Abort(.notFound, reason: "Playlist not found or access denied.")
        }
        let updateData = try req.content.decode(UpdateUserPlaylistData.self)
        playlist.name = updateData.name
        try await playlist.save(on: req.db)
        return playlist
    }

    @Sendable
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try await self.getUserFromPayload(req: req)
        let userID = try user.requireID()
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid playlist ID format.")
        }
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == userID)
            .first() else {
            throw Abort(.notFound, reason: "Playlist not found or access denied.")
        }
        try await playlist.$songs.detachAll(on: req.db)
        try await playlist.delete(on: req.db)
        return .noContent
    }

    @Sendable
    func addSong(req: Request) async throws -> HTTPStatus {
        let user = try await self.getUserFromPayload(req: req)
        let userID = try user.requireID()
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self),
              let songID = req.parameters.get("songID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid playlist or song ID format.")
        }
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == userID)
            .first() else {
            throw Abort(.notFound, reason: "Playlist not found or access denied.")
        }
        guard let song = try await Song.find(songID, on: req.db) else {
            throw Abort(.notFound, reason: "Song with ID \(songID) not found.")
        }

        let alreadyAttached = try await playlist.$songs.isAttached(to: song, on: req.db)
        if !alreadyAttached {
            try await playlist.$songs.attach(song, on: req.db)
            return .created
        } else {
            return .ok
        }
    }

    @Sendable
    func removeSong(req: Request) async throws -> HTTPStatus {
        let user = try await self.getUserFromPayload(req: req)
        let userID = try user.requireID()
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self),
              let songID = req.parameters.get("songID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid playlist or song ID format.")
        }
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == userID)
            .first() else {
            throw Abort(.notFound, reason: "Playlist not found or access denied.")
        }
        guard let song = try await Song.find(songID, on: req.db) else {
            return .noContent
        }

        try await playlist.$songs.detach(song, on: req.db)
        return .noContent
    }

    @Sendable
    func getSongs(req: Request) async throws -> [PlayableTrackDTO] {
        let user = try await self.getUserFromPayload(req: req)
        let userID = try user.requireID()
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Playlist ID parameter")
        }

        // First check if the playlist exists and belongs to the user
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == userID)
            .first() else {
            throw Abort(.notFound, reason: "Playlist not found or access denied")
        }

        // Load songs with their artists
        let songs = try await playlist.$songs.query(on: req.db)
            .with(\.$artist)
            .all()

        guard !songs.isEmpty else { return [] }

        // Get song IDs for AI song lookup
        let songIDs = try songs.map { try $0.requireID() }

        // Load AI songs for these songs
        let aiSongs = try await AiSong.query(on: req.db)
            .filter(\.$song.$id ~~ songIDs)
            .all()

        let aiSongMap = Dictionary(uniqueKeysWithValues: aiSongs.map { ($0.$song.id, $0) })

        // Create DTOs for each song using async map
        var result: [PlayableTrackDTO] = []
        for song in songs {
            // Ensure artist is loaded
            try await song.$artist.load(on: req.db)
            
            guard let artist = song.$artist.value else {
                throw Abort(.internalServerError, reason: "Artist not found for song \(try song.requireID())")
            }
            
            let correspondingAiSong = aiSongMap[try song.requireID()]
            let dto = try PlayableTrackDTO(song: song, artist: artist, aiSong: correspondingAiSong)
            result.append(dto)
        }
        
        return result
    }

    struct AddSongRequest: Content {
        let songId: String 
        let title: String
        let artistName: String
    }

    @Sendable
    func addSongByBody(req: Request) async throws -> HTTPStatus {
        let user = try await self.getUserFromPayload(req: req)
        let userID = try user.requireID()
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid playlist ID format.")
        }
        let data = try req.content.decode(AddSongRequest.self)
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == userID)
            .first() else {
            throw Abort(.notFound, reason: "Playlist not found or access denied.")
        }

        let artist: Artist
        if let foundArtist = try await Artist.query(on: req.db)
            .filter(\.$name == data.artistName)
            .first() {
            artist = foundArtist
        } else {
            let newArtist = Artist(name: data.artistName, debutYear: 2020)
            try await newArtist.save(on: req.db)
            artist = newArtist
        }

        let song: Song
        if let foundSong = try await Song.query(on: req.db)
            .filter(\.$musicKitStoreID == data.songId)
            .first() {
            song = foundSong
        } else {
            let newSong = Song(
                title: data.title,
                artistID: try artist.requireID(),
                genre: "Pop", // 기본값
                musicKitStoreID: data.songId
            )
            try await newSong.save(on: req.db)
            song = newSong
        }

        let alreadyAttached = try await playlist.$songs.isAttached(to: song, on: req.db)
        if !alreadyAttached {
            try await playlist.$songs.attach(song, on: req.db)
            return .created
        } else {
            return .ok
        }
    }
}
