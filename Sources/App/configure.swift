import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT

public func configure(_ app: Application) async throws {
    // MARK: Database
    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
        username: Environment.get("DATABASE_USERNAME") ?? "freedfreed",
        password: Environment.get("DATABASE_PASSWORD") ?? "soda1223!!",
        database: Environment.get("DATABASE_NAME") ?? "BeamMusicDB",
        tls: .prefer(try .init(configuration: .clientDefault)))
    ), as: .psql)
//    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
//        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
//        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
//        username: Environment.get("DATABASE_USERNAME") ?? "vapor_username",
//        password: Environment.get("DATABASE_PASSWORD") ?? "vapor_password",
//        database: Environment.get("DATABASE_NAME") ?? "vapor_database",
//        tls: .prefer(try .init(configuration: .clientDefault)))
//    ), as: .psql)

    // MARK: Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateArtist())
    app.migrations.add(CreateSong())
    app.migrations.add(CreateListeningHistory())
    app.migrations.add(CreateUserSongPreference())
    app.migrations.add(AddTestUser())
    app.migrations.add(CreateUserPlaylist())
    app.migrations.add(CreatePlaylistSong())
    app.http.server.configuration.hostname = "192.168.0.104"
        app.http.server.configuration.port = 8080
    // MARK: Middleware
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    app.jwt.signers.use(.hs256(key: "your-secret-key"))
    // MARK: Routes
    try app.autoMigrate().wait()
    try routes(app)
}

func createTestUser(app: Application) {
    _ = User.query(on: app.db)
        .filter(\.$username == "testuser")
        .first()
        .flatMap { existingUser in
            if existingUser == nil {
                do {
                    let hashedPassword = try Bcrypt.hash("password123")
                    
                    // 새 사용자 생성, 회원가입 todo..
                    let testUser = User(username: "testuser", email: "testuser@example.com", passwordHash: hashedPassword)
                    
                    return testUser.save(on: app.db)
                } catch {
                    return app.eventLoopGroup.future(error: error)
                }
            }
            return app.eventLoopGroup.future()
        }
}
