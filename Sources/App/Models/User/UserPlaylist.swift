//
//  UserPlaylist.swift
//  Beam-Music-Server
//
//  Created by freed on 9/26/24.
//
import Vapor
import Fluent

final class UserPlaylist: Model, Content, @unchecked Sendable {
    static let schema = "user_playlists"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Field(key: "user_id")
    var userID: UUID
    
    @Siblings(through: PlaylistSong.self, from: \.$playlist, to: \.$song)
    var songs: [Song]
    
    init() { }
    
    init(id: UUID? = nil, name: String, userID: UUID) {
        self.id = id
        self.name = name
        self.userID = userID
    }
}

// PlaylistSong 모델 정의 (Many-to-Many 관계를 위한 피벗 모델)
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
