import Fluent

struct CreateConvertedSong: AsyncMigration {
    func prepare(on database: Database) async throws {
        try await database.schema("converted_songs")
            .id()
            .field("user_id", .uuid, .required, .references("users", "id", onDelete: .cascade))
            .field("source_track_id", .string)
            .field("source_key", .string, .required)
            .field("source_playback_url", .string)
            .field("title", .string, .required)
            .field("artist_name", .string)
            .field("artwork_url", .string)
            .field("voice_id", .string, .required)
            .field("voice_name", .string, .required)
            .field("voice_type", .string)
            .field("status", .string, .required)
            .field("beam_svc_job_id", .string)
            .field("result_file_url", .string)
            .field("error_message", .string)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .unique(on: "user_id", "source_key", "voice_id")
            .create()
    }

    func revert(on database: Database) async throws {
        try await database.schema("converted_songs").delete()
    }
}
