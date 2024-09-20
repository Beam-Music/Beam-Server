//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//
import Vapor

struct SongDTO: Content {
    let id: UUID?
    let title: String
    let genre: String
    let releaseDate: Date
    let duration: Int
    let artist: String
    
    init(id: UUID? = nil, title: String, genre: String, releaseDate: Date, duration: Int, artist: String) {
        self.id = id
        self.title = title
        self.genre = genre
        self.releaseDate = releaseDate
        self.duration = duration
        self.artist = artist
    }
    
    init(from song: Song) {
        self.id = song.id
        self.title = song.title
        self.genre = song.genre
        self.releaseDate = song.releaseDate
        self.duration = song.duration
        self.artist = song.artist
    }
}

