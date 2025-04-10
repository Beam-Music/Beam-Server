//
//  RemoveArtistColumnFromSongs.swift
//  Beam-Music-Server
//
//  Created by anonymous on 4/10/25.
//

import Fluent

struct RemoveArtistColumnFromSongs: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("songs")
            .deleteField("artist") // "artist" 컬럼 삭제
            .update()
        print("Removed 'artist' column from songs table.")
    }

    func revert(on database: Database) async throws {
        // 되돌리기를 대비하여 원래 타입으로 컬럼을 다시 추가 (원래 타입을 알아야 함)
        // 예: 원래 타입이 .string이었다면
        // try await database.schema("songs")
        //     .field("artist", .string) // 원래 타입과 제약조건 확인 필요!
        //     .update()
        // print("Re-added 'artist' column to songs table.")

        // 만약 되돌리기가 복잡하거나 불필요하다면 revert 내용은 비워둘 수도 있음
        print("Skipping revert for RemoveArtistColumnFromSongs.")
    }
}
