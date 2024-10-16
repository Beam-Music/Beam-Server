import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import SendGrid

public func configure(_ app: Application) async throws {
    // MARK: Database
    if let databaseURL = Environment.get("DATABASE_URL"),
          var config = PostgresConfiguration(url: databaseURL) {
           config.tlsConfiguration = .makeClientConfiguration()
           app.databases.use(.postgres(configuration: config), as: .psql)
       } else {
           // Fallback configuration for local development
           app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
               hostname: Environment.get("DATABASE_HOST") ?? "localhost",
               port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
               username: Environment.get("DATABASE_USERNAME") ?? "freedfreed",
               password: Environment.get("DATABASE_PASSWORD") ?? "soda1223!!",
               database: Environment.get("DATABASE_NAME") ?? "BeamMusicDB",
               tls: .prefer(try .init(configuration: .clientDefault)))
           ), as: .psql)
       }

    //    app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
//        hostname: Environment.get("DATABASE_HOST") ?? "localhost",
//        port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
//        username: Environment.get("DATABASE_USERNAME") ?? "freedfreed",
//        password: Environment.get("DATABASE_PASSWORD") ?? "soda1223!!",
//        database: Environment.get("DATABASE_NAME") ?? "BeamMusicDB",
//        tls: .prefer(try .init(configuration: .clientDefault)))
//    ), as: .psql)
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
    app.migrations.add(CreateVerification())
//    app.http.server.configuration.hostname = "192.168.0.33"
//    app.http.server.configuration.port = 8080
    app.http.server.configuration.hostname = "0.0.0.0"
    app.http.server.configuration.port = Int(Environment.get("PORT") ?? "8080") ?? 8080

    // MARK: Middleware
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    app.jwt.signers.use(.hs256(key: "your-secret-key"))
    // MARK: Routes
    try await app.autoMigrate().get()
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
                    let testUser = User(username: "testuser", email: "testuser@example.com", passwordHash: hashedPassword)
                    return testUser.save(on: app.db)
                } catch {
                    return app.eventLoopGroup.future(error: error)
                }
            }
            return app.eventLoopGroup.future()
        }
}
