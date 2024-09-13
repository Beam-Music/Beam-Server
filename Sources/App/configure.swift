import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor

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

    // MARK: Migrations
    app.migrations.add(CreateUser())
    app.migrations.add(CreateArtist())
    app.migrations.add(CreateSong())
    app.migrations.add(CreateListeningHistory())
    app.migrations.add(CreateUserSongPreference())

    // MARK: Middleware
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    // MARK: Routes
    try routes(app)
}
