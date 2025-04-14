import Fluent

struct CreateAIPreferences: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("ai_preferences")
            .id()
            .field("user_id", .uuid, .required)
            .field("enable_ai_music", .bool, .required)
            .create()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("ai_preferences").delete()
    }
}

