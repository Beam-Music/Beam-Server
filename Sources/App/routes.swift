import Fluent
import Vapor

func routes(_ app: Application) throws {
    app.get { req async in
        "Welcome to Beam Music API!"
    }
    
    let protectedRoutes = app.grouped(TokenAuthMiddleware())
    try app.register(collection: UserController())
    try protectedRoutes.register(collection: AuthenticatedUserController())
    try app.register(collection: ArtistController())
    try app.register(collection: SongController())
//    try protectedRoutes.register(collection: ListeningHistoryController())

    try app.register(collection: ListeningHistoryController())
    try app.register(collection: UserSongPreferenceController())
}
