import Fluent

struct CreateAIPreference: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("ai_preferences")
            .id()
            .field("user_id", .uuid, .required)
            .field("enable_ai_music", .bool, .required)
            .field("created_at", .datetime)
            .field("updated_at", .datetime)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("ai_preferences").delete()
    }
}
