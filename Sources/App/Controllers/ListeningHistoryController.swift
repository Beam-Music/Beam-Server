//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//
import Vapor


struct HistoryQueryOptions: Content {
    var limit: Int?
    var startDate: Date?
    var endDate: Date?
    var genre: String?
    var sortBy: SortOption?
    
    enum SortOption: String, Content {
        case dateAsc, dateDesc, durationAsc, durationDesc
    }
}

struct ListeningHistoryController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let history = routes.grouped("listening-history")
        history.get(use: index)
        history.post(use: create)
        history.get("me", use: getMyHistory)
        history.get(":historyID", use: get)
        history.delete(":historyID", use: delete)
    }

    func index(req: Request) async throws -> [ListeningHistory] {
        try await ListeningHistory.query(on: req.db).all()
    }

    func create(req: Request) async throws -> ListeningHistory {
        let history = try req.content.decode(ListeningHistory.self)
        try await history.save(on: req.db)
        return history
    }
    
    func getMyHistory(req: Request) async throws -> [ListeningHistory] {
        let user = try req.auth.require(User.self)
        let options = try req.query.decode(HistoryQueryOptions.self)
        
        guard let userId = user.id else {
            throw Abort(.internalServerError, reason: "User ID is missing")
        }
        
        let query = ListeningHistory.query(on: req.db)
            .filter(\.$user.$id, .equal, userId)
        
        // 날짜 범위 필터
        if let startDate = options.startDate {
            query.filter(\.$listenedAt, .greaterThanOrEqual, startDate)
        }
        if let endDate = options.endDate {
            query.filter(\.$listenedAt, .lessThanOrEqual, endDate)
        }
        
        // 장르 필터
        if let genre = options.genre {
            query.filter(\.$genre, .equal, genre)
        }
        
        // 정렬
        switch options.sortBy {
        case .dateAsc:
            query.sort(\.$listenedAt, .ascending)
        case .dateDesc:
            query.sort(\.$listenedAt, .descending)
        case .durationAsc:
            query.sort(\.$playDuration, .ascending)
        case .durationDesc:
            query.sort(\.$playDuration, .descending)
        case .none:
            query.sort(\.$listenedAt, .descending)  // 기본 정렬
        }
        
        // 결과 제한
        if let limit = options.limit {
            query.limit(limit)
        }
        // GET /my-history?limit=50&startDate=2023-01-01T00:00:00Z&endDate=2023-12-31T23:59:59Z&genre=Rock&sortBy=durationDesc

        return try await query.all()
    }


    func get(req: Request) async throws -> ListeningHistory {
        guard let history = try await ListeningHistory.find(req.parameters.get("historyID"), on: req.db) else {
            throw Abort(.notFound)
        }
        return history
    }

    func delete(req: Request) async throws -> HTTPStatus {
        guard let history = try await ListeningHistory.find(req.parameters.get("historyID"), on: req.db) else {
            throw Abort(.notFound)
        }
        try await history.delete(on: req.db)
        return .noContent
    }
}

