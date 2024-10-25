//
//  CreateRecommendPlaylist.swift
//  Beam-Music-Server
//
//  Created by freed on 10/13/24.
//

import Fluent
import FluentSQL

//struct CreateRecommendPlaylist: AsyncMigration {
//    func prepare(on database: Database) async throws {
//        try await database.schema("playlist_recommendation")
//            .id()
//            .field("name", .string, .required)
//            .create()
//    }
//
//    func revert(on database: Database) async throws {
//        try await database.schema("playlist_recommendation").delete()
//    }
//}

struct CheckTableExists: Decodable {
    let exists: Bool
}

struct CreateRecommendPlaylist: AsyncMigration {
    func prepare(on database: Database) async throws {
        // database가 SQL을 지원하는지 확인
        guard let sqlDatabase = database as? SQLDatabase else {
            fatalError("SQLDatabase를 사용할 수 없습니다.")
        }

        // SQLQueryString 타입을 사용하여 쿼리 작성
        let checkTableQuery: SQLQueryString = """
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'playlist_recommendation'
        );
        """

        // SQL 쿼리를 실행하고 결과 확인
        let result = try await sqlDatabase.raw(checkTableQuery).first(decoding: CheckTableExists.self)

        // 쿼리 결과에 따라 테이블 생성 여부 결정
        if let existsResult = result, existsResult.exists == false {
            try await database.schema("playlist_recommendation")
                .id()
                .field("name", .string, .required)
                .create()
        } else {
            print("Table 'playlist_recommendation' already exists, skipping creation.")
        }
    }

    func revert(on database: Database) async throws {
        try await database.schema("playlist_recommendation").delete()
    }
}

struct CreateRecommendPlaylistSong: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("recommend_playlists_songs")
            .id()
            .field("playlist_id", .uuid, .required, .references("playlist_recommendation", "id"))
            .field("song_id", .uuid, .required, .references("songs", "id"))
            .ignoreExisting()
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("recommend_playlists_songs").delete()
    }
}
