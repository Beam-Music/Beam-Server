//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//
import Vapor

struct ArtistDTO: Content {
    let id: UUID?
    let name: String
    let debutYear: Int
    
    init(id: UUID? = nil, name: String, debutYear: Int) {
        self.id = id
        self.name = name
        self.debutYear = debutYear
    }
    
    init(from artist: Artist) {
        self.id = artist.id
        self.name = artist.name
        self.debutYear = artist.debutYear
    }
}

