// UserPlaylist.swift
import Vapor
import Fluent

final class UserPlaylist: Model, Content, @unchecked Sendable {
    static let schema = "user_playlists"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Parent(key: "user_id")
    var user: User

    @Siblings(through: PlaylistSong.self, from: \.$playlist, to: \.$song)
    var songs: [Song]

    init() { }
    init(id: UUID? = nil, name: String, userID: User.IDValue) {
        self.id = id
        self.name = name
        self.$user.id = userID
    }
}

final class PlaylistSong: Model, @unchecked Sendable {
    static let schema = "playlist_songs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "playlist_id")
    var playlist: UserPlaylist

    @Parent(key: "song_id")
    var song: Song

    init() { }

    init(id: UUID? = nil, playlist: UserPlaylist, song: Song) throws {
        self.id = id
        self.$playlist.id = try playlist.requireID()
        self.$song.id = try song.requireID()
    }
}
