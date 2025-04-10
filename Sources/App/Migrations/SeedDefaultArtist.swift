//
//  SeedDefaultArtist.swift
//  Beam-Music-Server
//
//  Created by anonymous on 4/10/25.
//

import Fluent
import Vapor

struct SeedDefaultArtist: AsyncMigration {
    func prepare(on database: Database) async throws {
        // 기본 아티스트 생성 (예: 이름 "AI Artist")
        let defaultArtist = Artist(name: "AI Artist", debutYear: 2025) // Artist 모델의 init 사용
        try await defaultArtist.save(on: database)
        print("Default artist seeded.")
    }

    func revert(on database: Database) async throws {
        // 이름으로 기본 아티스트 삭제
        try await Artist.query(on: database)
            .filter(\.$name == "AI Artist")
            .delete()
        print("Default artist reverted.")
    }
}
