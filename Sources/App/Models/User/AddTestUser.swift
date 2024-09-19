//
//  File.swift
//  
//
//  Created by freed on 9/19/24.
//

import Fluent
import Vapor
import Crypto

struct AddTestUser: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        // 비밀번호 해시화
        let hashedPassword = try! Bcrypt.hash("password123")

        // 사용자 생성
        let user = User(username: "testuser", email: "testuser@example.com", passwordHash: hashedPassword)
        
        // 데이터베이스에 저장
        return user.save(on: database)
    }

    func revert(on database: Database) -> EventLoopFuture<Void> {
        // 기본 사용자 삭제
        return User.query(on: database)
            .filter(\.$username == "testuser")
            .delete()
    }
}

