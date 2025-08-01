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
        config.tlsConfiguration?.certificateVerification = .none

        app.databases.use(.postgres(
            configuration: config,
            maxConnectionsPerEventLoop: 1,
            connectionPoolTimeout: .seconds(10)
        ), as: .psql)
    } else {
        guard let hostname = Environment.get("DATABASE_HOST") else {
            throw Abort(.internalServerError, reason: "Missing DATABASE_HOST environment variable.")
        }
        
        let portString = Environment.get("DATABASE_PORT")
        let port = portString.flatMap(Int.init) ?? SQLPostgresConfiguration.ianaPortNumber
        if portString == nil || portString.flatMap(Int.init) == nil {
            app.logger.warning("DATABASE_PORT environment variable missing or invalid. Using default port \(SQLPostgresConfiguration.ianaPortNumber).")
        }
        
        guard let username = Environment.get("DATABASE_USERNAME") else {
            throw Abort(.internalServerError, reason: "Missing DATABASE_USERNAME environment variable.")
        }
        let password = Environment.get("DATABASE_PASSWORD")
        if password == nil {
            app.logger.warning("DATABASE_PASSWORD environment variable not set.")
        }
        guard let databaseName = Environment.get("DATABASE_NAME") else {
            throw Abort(.internalServerError, reason: "Missing DATABASE_NAME environment variable.")
        }
        
        var config = SQLPostgresConfiguration(
            hostname: hostname,
            port: port,
            username: username,
            password: password,
            database: databaseName,
            tls: .disable
        )
        
        app.databases.use(.postgres(
            configuration: config,
            maxConnectionsPerEventLoop: 1,
            connectionPoolTimeout: .seconds(10)
        ), as: .psql)
    }
    
    app.migrations.add(CreateUser())
    // app.migrations.add(AddTestUser())
//    app.migrations.add(AddEmailAndPasswordToUser())
    app.migrations.add(CreateArtist())
    app.migrations.add(CreateRecommendPlaylist())
    app.migrations.add(CreateSong())
    app.migrations.add(CreateUserPlaylist())
    app.migrations.add(CreateVerification())
    
    app.migrations.add(CreateAISong())
    app.migrations.add(AddCreatedAtColumnToAiSongs())
    app.migrations.add(AddIsAIGeneratedToSongs())
    app.migrations.add(AddMusicKitStoreIDToSongs())
    
    app.migrations.add(CreateListeningHistory())
    app.migrations.add(CreateUserSongPreference())
    
    app.migrations.add(CreatePlaylistSong())
    app.migrations.add(AddOrderToPlaylistSong())
    app.migrations.add(CreateRecommendPlaylistSongPivot())

    app.migrations.add(BackfillAiSongSongID())
    // app.migrations.add(SeedDefaultArtist())
    // app.migrations.add(RemoveArtistColumnFromSongs())
    app.migrations.add(SeedAIMusic())
    // app.migrations.add(AddProfileImageURLToUsers())
    
    app.migrations.add(AddFavoriteArtistsAndGenresToUser())
    
    // MARK: Middleware
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    let jwtSecret = Environment.get("JWT_SECRET") ?? "your-very-secure-default-secret-key-replace-me"
    if jwtSecret == "your-very-secure-default-secret-key-replace-me" {
        app.logger.warning("Using default JWT secret. Set a strong JWT_SECRET environment variable in production.")
    }
    app.jwt.signers.use(.hs256(key: jwtSecret))
    
    // MARK: Server Configuration
    let serverHostname = Environment.get("HOST") ?? "0.0.0.0"
    let serverPort = Environment.get("PORT").flatMap(Int.init) ?? 8081
    app.http.server.configuration.hostname = serverHostname
    app.http.server.configuration.port = serverPort
    
    
    // MARK: Routes
    try routes(app)
    
    // MARK: Auto-migrate (Run migrations)
    if app.environment != .production {
        try await app.autoMigrate()
    } else {
        print("[Migration] Skipping auto-migration in production environment.")
    }
    
    if Environment.get("SENDGRID_API_KEY") != nil {
            app.sendgrid.initialize()
    } else {
        app.logger.warning("SENDGRID_API_KEY environment variable not set. SendGrid might not work correctly or will fail at runtime.")
    }

    // Lalal.ai 설정
    app.logger.info("Lalal.ai voice conversion system configured.")
    app.logger.info("Note: Using Lalal.ai cloud API for voice conversion features.")

        // Body size 제한 늘리기 (예: 100MB)
    app.routes.defaultMaxBodySize = "100mb"

    // 타임아웃 설정 늘리기
    app.http.server.configuration.requestDecompression = .enabled(limit: .none)
    app.http.server.configuration.responseCompression = .enabled
}
