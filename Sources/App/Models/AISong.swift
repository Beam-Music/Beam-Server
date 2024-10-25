//
//  AISong.swift
//  Beam-Music-Server
//
//  Created by freed on 10/25/24.
//

import Vapor
import Fluent

final class AISong: Model, Content {
    static let schema = "ai_songs"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "title")
    var title: String
    
    @Field(key: "artist")
    var artist: String
    
    @Field(key: "genre")
    var genre: String?
    
    @Field(key: "release_date")
    var releaseDate: Date?
    
    @Field(key: "duration")
    var duration: Int?
    
    @Field(key: "file_path")
    var filePath: String
    
    init() { }
    
    init(id: UUID? = nil, title: String, artist: String, genre: String? = nil, releaseDate: Date? = nil, duration: Int? = nil, filePath: String) {
        self.id = id
        self.title = title
        self.artist = artist
        self.genre = genre
        self.releaseDate = releaseDate
        self.duration = duration
        self.filePath = filePath
    }
}
