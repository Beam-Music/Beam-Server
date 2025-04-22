//
//  AddIsAIGeneratedToSongs.swift
//  Beam-Music-Server
//
//  Created by anonymous on 4/22/25.
//

import Fluent

struct AddIsAIGeneratedToSongs: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("songs") // "songs" 테이블을 수정
            // .field("is_ai_generated", .bool, .required) // 필수로 만들 경우
            .field("is_ai_generated", .bool, .sql(.default(false))) // 기본값을 false로 설정할 경우 (권장)
            .update() // 테이블 스키마 업데이트
    }

    func revert(on database: Database) async throws {
        try await database.schema("songs")
            .deleteField("is_ai_generated") // 필드 삭제
            .update()
    }
}
