import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import SendGrid


public func configure(_ app: Application) async throws {
    // MARK: Database
    // Force use individual DB variables instead of DATABASE_URL for local development
    let forceLocalDB = Environment.get("FORCE_LOCAL_DB") == "true" || Environment.get("DATABASE_HOST") != nil
    
    if !forceLocalDB, let databaseURL = Environment.get("DATABASE_URL"),
       var config = PostgresConfiguration(url: databaseURL) {
        // Log database connection info (mask password)
        if let url = URL(string: databaseURL) {
            let host = url.host(percentEncoded: false) ?? "unknown"
            let port = url.port ?? 5432
            let dbName = url.path(percentEncoded: false).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            app.logger.info("📊 Using DATABASE_URL: \(host):\(port)/\(dbName)")
        } else {
            app.logger.info("📊 Using DATABASE_URL (connection string)")
        }
        config.tlsConfiguration = .makeClientConfiguration()
        config.tlsConfiguration?.certificateVerification = .none

        app.databases.use(.postgres(
            configuration: config,
            maxConnectionsPerEventLoop: 4,
            connectionPoolTimeout: .seconds(30)
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
        
        // Use 127.0.0.1 instead of localhost for better compatibility
        let dbHostname = hostname == "localhost" ? "127.0.0.1" : hostname
        app.logger.info("📊 Using individual DATABASE variables: \(dbHostname):\(port)/\(databaseName) (user: \(username))")
        app.logger.info("📊 Password set: \(password != nil ? "Yes" : "No")")
        
        // Verify PostgreSQL is accessible before configuring
        app.logger.info("📊 Verifying PostgreSQL accessibility at \(dbHostname):\(port)...")
        
        var config = SQLPostgresConfiguration(
            hostname: dbHostname,
            port: port,
            username: username,
            password: password,
            database: databaseName,
            tls: .disable
        )
        
        // Increase timeout for local database connections
        let connectionTimeout: TimeAmount = dbHostname == "127.0.0.1" || dbHostname == "localhost"
            ? .seconds(60) 
            : .seconds(30)
        
        app.logger.info("📊 Configuring database with timeout: \(connectionTimeout.nanoseconds / 1_000_000_000) seconds")
        
        app.databases.use(.postgres(
            configuration: config,
            maxConnectionsPerEventLoop: 2, // Reduce for local DB
            connectionPoolTimeout: connectionTimeout
        ), as: .psql)
        
        app.logger.info("✅ Database configuration completed")
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
    app.migrations.add(CreateConvertedSong())
    
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
    guard let jwtSecret = Environment.get("JWT_SECRET"), !jwtSecret.isEmpty else {
        throw Abort(.internalServerError, reason: "JWT_SECRET environment variable must be set.")
    }
    if jwtSecret.count < 32 {
        app.logger.warning("JWT_SECRET should be at least 32 characters long for security.")
    }
    app.jwt.signers.use(.hs256(key: jwtSecret))
    
    // MARK: Server Configuration
    let serverHostname = Environment.get("HOST") ?? "0.0.0.0"
    let serverPort = Environment.get("PORT").flatMap(Int.init) ?? 8081
    app.http.server.configuration.hostname = serverHostname
    app.http.server.configuration.port = serverPort
    
    // 서버 타임아웃 설정 개선
    app.http.server.configuration.requestDecompression = .enabled(limit: .none)
    app.http.server.configuration.responseCompression = .enabled
    
    // Body size 제한 늘리기 (예: 100MB)
    app.routes.defaultMaxBodySize = "100mb"
    
    // 이벤트 루프 설정
    app.http.server.configuration.backlog = 256
    app.http.server.configuration.reuseAddress = true
    
    // MARK: Routes
    try routes(app)
    
    // MARK: Auto-migrate (Run migrations)
    if app.environment != .production {
        try await app.autoMigrate()
    } else {
        print("[Migration] Skipping auto-migration in production environment.")
    }
    
    // MARK: SendGrid Configuration
    if let apiKey = Environment.get("SENDGRID_API_KEY") {
        let keyPrefix = String(apiKey.prefix(5))
        let keySuffix = String(apiKey.suffix(5))
        app.logger.info("SendGrid API Key loaded: \(keyPrefix)...\(keySuffix)")
        app.logger.info("SendGrid API Key full length: \(apiKey.count) characters")
        
        // Initialize SendGrid with the API key
        app.sendgrid.initialize()
        app.logger.info("SendGrid initialized successfully")
    } else {
        app.logger.warning("SENDGRID_API_KEY environment variable not set. SendGrid might not work correctly or will fail at runtime.")
        let sendgridKeys = ProcessInfo.processInfo.environment.keys.filter { $0.contains("SENDGRID") || $0.contains("GRID") }
        if !sendgridKeys.isEmpty {
            app.logger.warning("Found related environment variables: \(sendgridKeys.joined(separator: ", "))")
        }
    }

    // Lalal.ai 설정
    app.logger.info("Lalal.ai voice conversion system configured.")
    app.logger.info("Note: Using Lalal.ai cloud API for voice conversion features.")
}
