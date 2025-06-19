//
//  File.swift
//  
//
//  Created by freed on 9/12/24.
//

import Fluent
import Vapor

final class User: Model, Content, @unchecked Sendable {
    static let schema = "users"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "username")
    var username: String

    @Field(key: "email")
    var email: String

//    @Field(key: "password")
//    var password: String
    
    @Field(key: "password_hash")
    var passwordHash: String

    @Field(key: "is_verified")
    var isVerified: Bool

    @OptionalField(key: "profile_image_url")
    var profileImageURL: String?

    @Field(key: "favorite_artists")
    var favoriteArtists: [String]

    @Field(key: "favorite_genres")
    var favoriteGenres: [String]
    
    init() {}
    
    init(id: UUID? = nil, username: String, email: String, passwordHash: String, isVerified: Bool = false, profileImageURL: String? = nil, favoriteArtists: [String] = [], favoriteGenres: [String] = []) {
        self.id = id
        self.username = username
        self.email = email
        self.passwordHash = passwordHash
        self.isVerified = isVerified
        self.profileImageURL = profileImageURL
        self.favoriteArtists = favoriteArtists
        self.favoriteGenres = favoriteGenres
    }
}
