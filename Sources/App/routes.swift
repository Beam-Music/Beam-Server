import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "Welcome to Beam Music API!"
    }

    try app.register(collection: UserController())
    try app.register(collection: ArtistController())
    try app.register(collection: SongController())
    try app.register(collection: ListeningHistoryController())
    try app.register(collection: UserSongPreferenceController())
    try app.register(collection: UserPlaylistController())
    try app.register(collection: RecommendPlaylistController())
}
