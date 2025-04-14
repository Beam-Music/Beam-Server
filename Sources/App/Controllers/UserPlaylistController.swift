import Vapor
import Fluent
import JWT

struct UserPlaylistController: RouteCollection {
    
    func boot(routes: RoutesBuilder) throws {
        let jwtProtected = routes.grouped(JWTMiddleware())
        let playlists = jwtProtected.grouped("user-playlists")
        
        playlists.get { [self] req async throws -> [PlaylistSummaryDTO] in
            try await self.index(req: req)
        }
        playlists.post { [self] req async throws -> UserPlaylist in
            try await self.create(req: req)
        }
        playlists.get(":playlistID") { [self] req async throws -> UserPlaylist in
            try await self.get(req: req)
        }
        playlists.put(":playlistID") { [self] req async throws -> UserPlaylist in
            try await self.update(req: req)
        }
        playlists.delete(":playlistID") { [self] req async throws -> HTTPStatus in
            try await self.delete(req: req)
        }
        playlists.post(":playlistID", "songs", ":songID") { [self] req async throws -> HTTPStatus in
            try await self.addSong(req: req)
        }
        playlists.delete(":playlistID", "songs", ":songID") { [self] req async throws -> HTTPStatus in
            try await self.removeSong(req: req)
        }
        playlists.get(":playlistID", "songs") { [self] req async throws -> [PlayableTrackDTO] in
            try await self.getSongs(req: req)
        }
    }
    
    private func getUserFromPayload(req: Request) async throws -> User {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.query(on: req.db)
            .filter(\.$username == payload.username)
            .first() else {
            throw Abort(.unauthorized, reason: "User not found for payload")
        }
        _ = try user.requireID()
        return user
    }
  
    func index(req: Request) async throws -> [PlaylistSummaryDTO] {
        let user = try await self.getUserFromPayload(req: req)
        let playlists = try await UserPlaylist.query(on: req.db)
            .filter(\.$user.$id == user.requireID())
            .all()
        return playlists.map { PlaylistSummaryDTO(id: $0.id, name: $0.name) }
    }
    
    func create(req: Request) async throws -> UserPlaylist {
        let user = try await self.getUserFromPayload(req: req)
        let createData = try req.content.decode(CreateUserPlaylistData.self)
        let playlist = UserPlaylist(name: createData.name, userID: try user.requireID())
        try await playlist.save(on: req.db)
        return playlist
    }
    
    func get(req: Request) async throws -> UserPlaylist {
        let user = try await self.getUserFromPayload(req: req)
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else { throw Abort(.badRequest) }
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == user.requireID())
            .first() else { throw Abort(.notFound) }
        return playlist
    }
    
    func update(req: Request) async throws -> UserPlaylist {
        let user = try await self.getUserFromPayload(req: req)
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else { throw Abort(.badRequest) }
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == user.requireID())
            .first() else { throw Abort(.notFound) }
        let updateData = try req.content.decode(UpdateUserPlaylistData.self)
        playlist.name = updateData.name
        try await playlist.save(on: req.db)
        return playlist
    }
    
    func delete(req: Request) async throws -> HTTPStatus {
        let user = try await self.getUserFromPayload(req: req)
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else { throw Abort(.badRequest) }
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == user.requireID())
            .first() else { throw Abort(.notFound) }
        try await playlist.$songs.detachAll(on: req.db)
        try await playlist.delete(on: req.db)
        return .noContent
    }
    
    func addSong(req: Request) async throws -> HTTPStatus {
        let user = try await self.getUserFromPayload(req: req)
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self),
              let songID = req.parameters.get("songID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == user.requireID())
            .first() else {
            throw Abort(.notFound)
        }
        guard let song = try await Song.find(songID, on: req.db) else {
            throw Abort(.notFound)
        }
        
        let alreadyAttached = try await playlist.$songs.isAttached(to: song, on: req.db)
        if !alreadyAttached {
            try await playlist.$songs.attach(song, on: req.db)
            return .created
        } else {
            return .ok
        }
    }
    
    func removeSong(req: Request) async throws -> HTTPStatus {
        let user = try await self.getUserFromPayload(req: req)
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self),
              let songID = req.parameters.get("songID", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == user.requireID())
            .first() else {
            throw Abort(.notFound)
        }
        guard let song = try await Song.find(songID, on: req.db) else {
            return .noContent
        }
        
        try await playlist.$songs.detach(song, on: req.db)
        return .noContent
    }
    
    func getSongs(req: Request) async throws -> [PlayableTrackDTO] {
        let user = try await self.getUserFromPayload(req: req)
        let userID = try user.requireID()
        guard let playlistID = req.parameters.get("playlistID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid Playlist ID parameter")
        }
        
        let playlistQuery = UserPlaylist.query(on: req.db)
            .filter(\.$id == playlistID)
            .filter(\.$user.$id == userID)
            .with(\.$songs) { songBuilder in
                songBuilder.with(\.$artist)
            }
        
        guard let playlist = try await playlistQuery.first() else {
            throw Abort(.notFound, reason: "Playlist not found or access denied")
        }
        
        let songs = playlist.songs
        guard !songs.isEmpty else { return [] }
        
        let songIDs = try songs.map { try $0.requireID() }
        let aiSongs = try await AiSong.query(on: req.db)
            .filter(\.$songId ~~ songIDs)
            .all()
        let aiSongMap = Dictionary(uniqueKeysWithValues: aiSongs.map { ($0.songId, $0) })
        
        return try songs.map { song -> PlayableTrackDTO in
            guard let artist = song.$artist.value else {
                throw Abort(.internalServerError, reason: "Artist relation value not loaded correctly for song \(try song.requireID())")
            }
            let correspondingAiSong = aiSongMap[try song.requireID()]
            return try PlayableTrackDTO(song: song, artist: artist, aiSong: correspondingAiSong)
        }
    }
}

extension Array where Element == Song {
    func loadArtists(on database: Database) async throws {
        guard !self.isEmpty else { return }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for song in self {
                group.addTask {
                    try await song.$artist.load(on: database)
                }
            }
            try await group.waitForAll()
        }
    }
}
