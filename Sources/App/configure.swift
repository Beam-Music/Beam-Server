import NIOSSL
import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import SendGrid
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
    app.migrations.add(AddTestUser())
    app.migrations.add(AddTokenToUsers())
    app.migrations.add(AddEmailVerificationFieldsToUser())
    app.sendgrid.initialize()

    // MARK: Middleware
    app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))
    app.middleware.use(ErrorMiddleware.default(environment: app.environment))

    app.jwt.signers.use(.hs256(key: "your-secret-key"))
    // MARK: Routes
    try app.autoMigrate().wait()
    try routes(app)
}

func createTestUser(app: Application) {
    // 이미 사용자 생성되어 있는지 확인
    _ = User.query(on: app.db)
        .filter(\.$username == "testuser")
        .first()
        .flatMap { existingUser in
            if existingUser == nil {
                do {
                    // 비밀번호 해시화
                    let hashedPassword = try Bcrypt.hash("password123")
                    
                    // 새 사용자 생성
                    let testUser = User(username: "testuser", email: "testuser@example.com", passwordHash: hashedPassword)
                    
                    // 데이터베이스에 저장
                    return testUser.save(on: app.db)
                } catch {
                    return app.eventLoopGroup.future(error: error)
                }
            }
            return app.eventLoopGroup.future()
        }
}
