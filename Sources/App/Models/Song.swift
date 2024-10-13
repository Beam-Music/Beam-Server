//
//  File.swift
//  
//
//  Created by freed on 9/12/24.
//
import Fluent
import Vapor

final class Song: Model, Content {
    static let schema = "songs"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "title")
    var title: String
    
    @Field(key: "genre")
    var genre: String

    @Field(key: "release_date")
    var releaseDate: Date

    @Field(key: "duration")
    var duration: Int

    @OptionalParent(key: "artist_id")
    var artist: Artist?

    init() { }

    init(id: UUID? = nil, title: String, genre: String, releaseDate: Date, duration: Int, artistID: UUID) {
        self.id = id
        self.title = title
        self.genre = genre
        self.releaseDate = releaseDate
        self.duration = duration
        self.$artist.id = artistID
    }
}

