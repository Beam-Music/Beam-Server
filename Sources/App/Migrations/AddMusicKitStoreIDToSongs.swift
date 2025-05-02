import Fluent

struct AddMusicKitStoreIDToSongs: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("songs")
            .field("music_kit_store_id", .string)
            .update()
    }

    func revert(on database: Database) async throws {
        try await database.schema("songs")
            .deleteField("music_kit_store_id")
            .update()
    }
} 