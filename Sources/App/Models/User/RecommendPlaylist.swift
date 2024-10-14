//
//  RecommendPlaylist.swift
//  Beam-Music-Server
//
//  Created by freed on 10/13/24.
//

import Vapor
import Fluent

final class RecommendPlaylist: Model, Content {
    static let schema = "playlist_recommendation"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "name")
    var name: String
    
    @Siblings(through: RecommendPlaylistSong.self, from: \.$playlist, to: \.$song)
    var songs: [Song]
    
    init() { }
    
    init(id: UUID? = nil, name: String) {
        self.id = id
        self.name = name
    }
}

// RecommendPlaylistSong 피벗 모델 정의 (Many-to-Many 관계)
final class RecommendPlaylistSong: Model {
    static let schema = "recommend_playlists_songs"
    
    @ID(key: .id)
    var id: UUID?
    
    @Parent(key: "playlist_id")
    var playlist: RecommendPlaylist
    
    @Parent(key: "song_id")
    var song: Song
    
    init() { }
    
    init(id: UUID? = nil, playlist: RecommendPlaylist, song: Song) throws {
        self.id = id
        self.$playlist.id = try playlist.requireID()
        self.$song.id = try song.requireID()
    }
}
