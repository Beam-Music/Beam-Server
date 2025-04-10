import Fluent

struct AddAIGeneratedToSong: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("songs")
            .field("is_ai_generated", .bool, .required, .sql(.default(false)))
            .update()
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return database.schema("songs")
            .deleteField("is_ai_generated")
            .update()
    }
}
