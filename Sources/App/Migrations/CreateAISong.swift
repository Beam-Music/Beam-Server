//
//  CreateAISong.swift
//  Beam-Music-Server
//
//  Created by anonymous on 4/9/25.
//

import Fluent

struct CreateAISong: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("ai_songs")
            .id() // 기본적으로 UUID 타입의 'id' 컬럼 생성
            .field("title", .string, .required)
            .field("genre", .string)
            .field("release_date", .date)
            .field("duration", .int, .required)
            .field("is_ai_generated", .bool, .required)
            .field("file_url", .string, .required) 
            .field("song_id", .uuid, .references("songs", "id"))
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("ai_songs").delete()
    }
}
