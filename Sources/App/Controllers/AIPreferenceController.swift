import Vapor
import Fluent

struct AIPreferenceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let aiPreferences = routes.grouped("api", "ai-preferences")
        
        aiPreferences.get(":userId", use: getHandler)
        aiPreferences.put(":userId", use: updateHandler)
    }
    
    func getHandler(_ req: Request) throws -> EventLoopFuture<AIPreference> {
        guard let userIdString = req.parameters.get("userId"),
              let userId = UUID(uuidString: userIdString) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        req.logger.info("Getting AI preference for user: \(userId)")
        
        return AIPreference.query(on: req.db)
            .filter(\AIPreference.$userId == userId)
            .first()
            .unwrap(or: Abort(.notFound, reason: "AI preference not found for user"))
    }
    
    func updateHandler(_ req: Request) throws -> EventLoopFuture<AIPreference> {
        guard let userIdString = req.parameters.get("userId"),
              let userId = UUID(uuidString: userIdString) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        req.logger.info("Received AI preference update request for user: \(userId)")
        
        let input = try req.content.decode(AIPreferenceInput.self)
        req.logger.info("Preference value: \(input.enableAIMusic)")
        
        return AIPreference.query(on: req.db)
            .filter(\AIPreference.$userId == userId)
            .first()
            .flatMap { existingPreference in
                if let preference = existingPreference {
                    preference.enableAIMusic = input.enableAIMusic
                    req.logger.info("Updated AI preference for user: \(userId)")
                    return preference.save(on: req.db).map { preference }
                } else {
                    let newPreference = AIPreference(
                        userId: userId,
                        enableAIMusic: input.enableAIMusic
                    )
                    req.logger.info("Created AI preference for user: \(userId)")
                    return newPreference.save(on: req.db).map { newPreference }
                }
            }
    }
}

struct AIPreferenceInput: Content {
    let userId: UUID
    let enableAIMusic: Bool
}
