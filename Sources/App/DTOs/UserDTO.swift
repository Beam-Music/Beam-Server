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
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let tokenType: String?
    
    init(id: UUID? = nil, username: String, email: String, profileImageURL: String? = nil, favoriteArtists: [String] = [], favoriteGenres: [String] = [], accessToken: String? = nil, refreshToken: String? = nil, expiresIn: Int? = nil, tokenType: String? = nil) {
        self.id = id
        self.username = username
        self.email = email
        self.profileImageURL = profileImageURL
        self.favoriteArtists = favoriteArtists
        self.favoriteGenres = favoriteGenres
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.tokenType = tokenType
    }
    
    init(from user: User, accessToken: String? = nil, refreshToken: String? = nil, expiresIn: Int? = nil, tokenType: String? = nil) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
        self.profileImageURL = user.profileImageURL
        self.favoriteArtists = user.favoriteArtists
        self.favoriteGenres = user.favoriteGenres
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresIn = expiresIn
        self.tokenType = tokenType
    }
    
    // Backward compatibility
    init(from user: User, token: String? = nil) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
        self.profileImageURL = user.profileImageURL
        self.favoriteArtists = user.favoriteArtists
        self.favoriteGenres = user.favoriteGenres
        self.accessToken = token
        self.refreshToken = nil
        self.expiresIn = nil
        self.tokenType = nil
    }
}

struct CreateUserDTO: Content {
    let username: String
    let email: String
    let password: String
}
