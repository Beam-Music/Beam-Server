//
//  File 2.swift
//  
//
//  Created by freed on 9/13/24.
//

import Vapor

struct UserDTO: Content {
    let id: UUID?
    let username: String
    let email: String
    let profileImageURL: String?
    let favoriteArtists: [String]
    let favoriteGenres: [String]
    
    init(id: UUID? = nil, username: String, email: String, profileImageURL: String? = nil, favoriteArtists: [String] = [], favoriteGenres: [String] = []) {
        self.id = id
        self.username = username
        self.email = email
        self.profileImageURL = profileImageURL
        self.favoriteArtists = favoriteArtists
        self.favoriteGenres = favoriteGenres
    }
    
    init(from user: User) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
        self.profileImageURL = user.profileImageURL
        self.favoriteArtists = user.favoriteArtists
        self.favoriteGenres = user.favoriteGenres
    }
}

struct CreateUserDTO: Content {
    let username: String
    let email: String
    let password: String
}
