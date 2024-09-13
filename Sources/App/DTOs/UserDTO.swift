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
    
    init(id: UUID? = nil, username: String, email: String) {
        self.id = id
        self.username = username
        self.email = email
    }
    
    init(from user: User) {
        self.id = user.id
        self.username = user.username
        self.email = user.email
    }
}

struct CreateUserDTO: Content {
    let username: String
    let email: String
    let password: String
}
