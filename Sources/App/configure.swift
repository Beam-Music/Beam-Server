import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import SendGrid

public func configure(_ app: Application) async throws {
    // MARK: Database
//    if let databaseURL = Environment.get("DATABASE_URL") {
//       let config = try SQLPostgresConfiguration(url: databaseURL)
//        app.databases.use(.postgres(
//            configuration: config,
//            maxConnectionsPerEventLoop: 1,
//            connectionPoolTimeout: .seconds(10)
//        ), as: .psql)
//    } else {
//        app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
//            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
//            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? SQLPostgresConfiguration.ianaPortNumber,
//            username: Environment.get("DATABASE_USERNAME") ?? "your-username",
//            password: Environment.get("DATABASE_PASSWORD") ?? "your-password",
//            database: Environment.get("DATABASE_NAME") ?? "your-database",
//            tls: .prefer(try .init(configuration: .clientDefault))),
//            maxConnectionsPerEventLoop: 1,
//            connectionPoolTimeout: .seconds(10)
//        ), as: .psql)
//    }
    if let databaseURL = Environment.get("DATABASE_URL"),
       var config = PostgresConfiguration(url: databaseURL) {
        config.tlsConfiguration = .makeClientConfiguration()
        config.tlsConfiguration?.certificateVerification = .none

        app.databases.use(.postgres(
            configuration: config,
            maxConnectionsPerEventLoop: 1,
            connectionPoolTimeout: .seconds(10)
        ), as: .psql)
    } else {
        app.databases.use(DatabaseConfigurationFactory.postgres(configuration: .init(
            hostname: Environment.get("DATABASE_HOST") ?? "localhost",
            port: Environment.get("DATABASE_PORT").flatMap(Int.init(_:)) ?? PostgresConfiguration.ianaPortNumber,
            username: Environment.get("DATABASE_USERNAME") ?? "your-username",
            password: Environment.get("DATABASE_PASSWORD") ?? "your-password",
            database: Environment.get("DATABASE_NAME") ?? "your-database",
            tls: .prefer(try .init(configuration: .clientDefault))),
            maxConnectionsPerEventLoop: 1,
            connectionPoolTimeout: .seconds(10)
        ), as: .psql)
    }


    // MARK: Migrations
    app.migrations.add(AddPasswordHashToUser())
    app.migrations.add(AddIsVerifiedToUser())
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
                    // 비밀번호를 해시화하여 사용자 객체 생성
                    let hashedPassword = try Bcrypt.hash("password123")
                    let testUser = User(username: "testuser", email: "testuser@example.com", passwordHash: hashedPassword)
                    return testUser.save(on: app.db)
                } catch {
                    // 에러 처리
                    return app.eventLoopGroup.future(error: error)
                }
            }
            return app.eventLoopGroup.future()
        }
}

