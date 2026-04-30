import Vapor
import Fluent

struct AIPreferenceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let aiPreferences = routes.grouped("api", "ai-preferences")
            .grouped(JWTMiddleware())

        aiPreferences.get(":userId", use: getHandler)
        aiPreferences.put(":userId", use: updateHandler)
    }

    @Sendable
    func getHandler(_ req: Request) async throws -> AIPreference {
        let payload = try req.auth.require(UserPayload.self)
        guard let userIdString = req.parameters.get("userId"),
              let userId = UUID(uuidString: userIdString) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        guard userId == payload.userId else {
            throw Abort(.forbidden, reason: "You can only access your own AI preferences")
        }

        guard let preference = try await AIPreference.query(on: req.db)
            .filter(\AIPreference.$userId == userId)
            .first() else {
            throw Abort(.notFound, reason: "AI preference not found for user")
        }
        return preference
    }

    @Sendable
    func updateHandler(_ req: Request) async throws -> AIPreference {
        let payload = try req.auth.require(UserPayload.self)
        guard let userIdString = req.parameters.get("userId"),
              let userId = UUID(uuidString: userIdString) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        guard userId == payload.userId else {
            throw Abort(.forbidden, reason: "You can only update your own AI preferences")
        }

        let input = try req.content.decode(AIPreferenceInput.self)

        if let preference = try await AIPreference.query(on: req.db)
            .filter(\AIPreference.$userId == userId)
            .first() {
            preference.enableAIMusic = input.enableAIMusic
            try await preference.save(on: req.db)
            return preference
        } else {
            let newPreference = AIPreference(
                userId: userId,
                enableAIMusic: input.enableAIMusic
            )
            try await newPreference.save(on: req.db)
            return newPreference
        }
    }
}

struct AIPreferenceInput: Content {
    let userId: UUID
    let enableAIMusic: Bool
}
