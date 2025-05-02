import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import SendGrid

public func configure(_ app: Application) async throws {
    // MARK: Database
    var tlsConfiguration = TLSConfiguration.makeClientConfiguration()
    tlsConfiguration.certificateVerification = .none
    
    // Database configuration from environment variables
    guard let databaseURL = Environment.get("DATABASE_URL") else {
        app.logger.error("DATABASE_URL not found in environment variables")
        throw Abort(.internalServerError, reason: "Database URL not configured")
    }
    
    guard let url = URL(string: databaseURL) else {
        throw Abort(.internalServerError, reason: "Invalid DATABASE_URL format")
    }
    
    let configuration = SQLPostgresConfiguration(
        hostname: url.host ?? "localhost",
        port: url.port ?? 5432,
        username: url.user ?? "postgres",
        password: url.password ?? "",
        database: url.lastPathComponent,
        tls: .prefer(try .init(configuration: tlsConfiguration))
    )
    
    app.logger.info("Connecting to database at host: \(url.host ?? "localhost")")
    
    app.databases.use(.postgres(
        configuration: configuration,
        maxConnectionsPerEventLoop: 2,
        connectionPoolTimeout: .seconds(60)
    ), as: .psql)
    
    app.migrations.add(CreateUser())
    app.migrations.add(AddTestUser())
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
    app.migrations.add(CreateRecommendPlaylistSongPivot())

    app.migrations.add(BackfillAiSongSongID())
    app.migrations.add(SeedAIMusic())
    
    // MARK: Middleware
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))
    
    // JWT Configuration
    let jwtSecret = Environment.get("JWT_SECRET") ?? "your-very-secure-default-secret-key-replace-me"
    if jwtSecret == "your-very-secure-default-secret-key-replace-me" {
        app.logger.warning("Using default JWT secret. Set a strong JWT_SECRET environment variable in production.")
    }
    app.jwt.signers.use(.hs256(key: jwtSecret))
    
    // MARK: Server Configuration
    let serverHostname = Environment.get("HOST") ?? "0.0.0.0"
    let serverPort = Environment.get("PORT").flatMap(Int.init) ?? 8080
    app.http.server.configuration.hostname = serverHostname
    app.http.server.configuration.port = serverPort
    print("[Server] Configured to bind to \(serverHostname):\(serverPort)")
    
    // MARK: Routes
    try routes(app)
    
    // MARK: Auto-migrate (Run migrations)
    if app.environment != .production {
        print("[Migration] Starting auto-migration...")
        try await app.autoMigrate()
        print("[Migration] Auto-migration finished.")
    } else {
        print("[Migration] Skipping auto-migration in production environment.")
    }
    
    // Configure SendGrid
    guard let sendgridApiKey = Environment.get("SENDGRID_API_KEY") else {
        app.logger.warning("SendGrid API key not found in environment variables")
        return
    }
    app.sendGridClient = SendGridClient(httpClient: app.http.client.shared, apiKey: sendgridApiKey)
    print("[SendGrid] Initialized.")
} 