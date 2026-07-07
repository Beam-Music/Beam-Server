import Vapor
import Fluent
import JWT

struct CreateConvertedSongRequestDTO: Content {
    let sourceTrackId: String?
    let sourcePlaybackUrl: String?
    let title: String
    let artistName: String?
    let artworkUrl: String?
    let voiceId: String
    let voiceName: String
    let voiceType: String?
}

struct ConvertedSongResponseDTO: Content {
    let id: UUID
    let sourceTrackId: String?
    let sourcePlaybackUrl: String?
    let title: String
    let artistName: String?
    let artworkUrl: String?
    let voiceId: String
    let voiceName: String
    let voiceType: String?
    let status: String
    let jobId: String?
    let resultFileUrl: String?
    let errorMessage: String?
    let createdAt: Date?
    let updatedAt: Date?
}

struct ConvertedSongCreateResponseDTO: Content {
    let id: UUID
    let status: String
    let jobId: String?
    let isDuplicate: Bool
}

struct ConvertedSongStatusResponseDTO: Content {
    let id: UUID
    let status: String
    let progress: Int?
    let stage: String?
    let resultFileUrl: String?
    let errorMessage: String?
}

struct ConvertedSongPlayableDTO: Content {
    let id: UUID
    let title: String
    let artistName: String?
    let playbackUrl: String?
    let fileUrl: String?
    let artworkUrl: String?
    let isAIGenerated: Bool
}

struct BeamSVCAcceptedResponse: Decodable {
    let jobId: String
    let status: String
}

struct BeamSVCJobStatusResponse: Decodable {
    let jobId: String
    let status: String
    let progress: Int?
    let stage: String?
    let resultUrl: String?
    let resultPath: String?
    let error: String?
}

struct ConvertedSongController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let jwtProtected = routes.grouped(JWTMiddleware())
        let convertedSongs = jwtProtected.grouped("api", "converted-songs")
        let publicConvertedSongs = routes.grouped("api", "converted-songs")

        convertedSongs.post(use: create)
        convertedSongs.get(use: list)
        convertedSongs.get("playable", use: playable)
        convertedSongs.group(":convertedSongID") { song in
            song.get(use: detail)
        }
        publicConvertedSongs.group(":convertedSongID") { song in
            song.get("audio", use: audio)
        }
    }

    private var beamSVCBaseURL: String {
        Environment.get("BEAM_SVC_URL") ?? "http://213.173.104.8:46399"
    }

    private func getUserFromPayload(req: Request) async throws -> User {
        let payload = try req.auth.require(UserPayload.self)
        guard let user = try await User.find(payload.userId, on: req.db) else {
            throw Abort(.unauthorized, reason: "User not found for provided token payload.")
        }
        return user
    }

    @Sendable
    func create(req: Request) async throws -> ConvertedSongCreateResponseDTO {
        let user = try await getUserFromPayload(req: req)
        let userID = try user.requireID()
        let body = try req.content.decode(CreateConvertedSongRequestDTO.self)

        let sourceKey = makeSourceKey(sourceTrackId: body.sourceTrackId, sourcePlaybackUrl: body.sourcePlaybackUrl, title: body.title, artistName: body.artistName)

        if let existing = try await ConvertedSong.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$sourceKey == sourceKey)
            .filter(\.$voiceID == body.voiceId)
            .first() {
            try await refreshStatusIfNeeded(req: req, song: existing)
            return try ConvertedSongCreateResponseDTO(
                id: existing.requireID(),
                status: existing.status,
                jobId: existing.beamSVCJobID,
                isDuplicate: true
            )
        }

        guard let sourcePlaybackUrl = body.sourcePlaybackUrl,
              let sourceURL = URL(string: sourcePlaybackUrl) else {
            throw Abort(.badRequest, reason: "sourcePlaybackUrl is required")
        }

        let (audioData, response) = try await URLSession.shared.data(from: sourceURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              !audioData.isEmpty else {
            throw Abort(.badGateway, reason: "Failed to download source audio")
        }

        let svcResponse = try await submitJobToBeamSVC(
            audioData: audioData,
            filename: sanitizedFileName(title: body.title) + ".mp3",
            voiceId: body.voiceId,
            voiceType: body.voiceType
        )

        let convertedSong = ConvertedSong(
            userID: userID,
            sourceTrackID: body.sourceTrackId,
            sourceKey: sourceKey,
            sourcePlaybackURL: body.sourcePlaybackUrl,
            title: body.title,
            artistName: body.artistName,
            artworkURL: body.artworkUrl,
            voiceID: body.voiceId,
            voiceName: body.voiceName,
            voiceType: body.voiceType,
            status: svcResponse.status,
            beamSVCJobID: svcResponse.jobId,
            resultFileURL: nil,
            errorMessage: nil
        )
        try await convertedSong.save(on: req.db)

        return try ConvertedSongCreateResponseDTO(
            id: convertedSong.requireID(),
            status: convertedSong.status,
            jobId: convertedSong.beamSVCJobID,
            isDuplicate: false
        )
    }

    @Sendable
    func list(req: Request) async throws -> [ConvertedSongResponseDTO] {
        let user = try await getUserFromPayload(req: req)
        let userID = try user.requireID()

        var query = ConvertedSong.query(on: req.db)
            .filter(\.$user.$id == userID)
            .sort(\.$createdAt, .descending)

        if let status = req.query[String.self, at: "status"], !status.isEmpty {
            query = query.filter(\.$status == status)
        }
        if let voiceId = req.query[String.self, at: "voiceId"], !voiceId.isEmpty {
            query = query.filter(\.$voiceID == voiceId)
        }
        if let limit = req.query[Int.self, at: "limit"] {
            query = query.limit(limit)
        }
        if let offset = req.query[Int.self, at: "offset"] {
            query = query.offset(offset)
        }

        let songs = try await query.all()
        for song in songs where song.status == "queued" || song.status == "processing" {
            try await refreshStatusIfNeeded(req: req, song: song)
        }
        return try songs.map { try makeResponseDTO(req: req, song: $0) }
    }

    @Sendable
    func detail(req: Request) async throws -> ConvertedSongStatusResponseDTO {
        let song = try await findOwnedSong(req: req)
        let latestStatus = try await refreshStatusIfNeeded(req: req, song: song)
        return try ConvertedSongStatusResponseDTO(
            id: song.requireID(),
            status: song.status,
            progress: latestStatus?.progress,
            stage: latestStatus?.stage,
            resultFileUrl: song.status == "completed" ? makeAudioProxyURL(req: req, songID: song.requireID()) : nil,
            errorMessage: song.errorMessage
        )
    }

    @Sendable
    func playable(req: Request) async throws -> [ConvertedSongPlayableDTO] {
        let user = try await getUserFromPayload(req: req)
        let userID = try user.requireID()
        let songs = try await ConvertedSong.query(on: req.db)
            .filter(\.$user.$id == userID)
            .filter(\.$status == "completed")
            .sort(\.$createdAt, .descending)
            .all()

        return try songs.map {
            try ConvertedSongPlayableDTO(
                id: $0.requireID(),
                title: "\($0.title) (Voice: \($0.voiceName))",
                artistName: $0.artistName,
                playbackUrl: makeAudioProxyURL(req: req, songID: try $0.requireID()),
                fileUrl: makeAudioProxyURL(req: req, songID: try $0.requireID()),
                artworkUrl: $0.artworkURL,
                isAIGenerated: true
            )
        }
    }

    @Sendable
    func audio(req: Request) async throws -> Response {
        guard let convertedSongID = req.parameters.get("convertedSongID", as: UUID.self),
              let song = try await ConvertedSong.find(convertedSongID, on: req.db) else {
            throw Abort(.notFound, reason: "Converted song not found")
        }
        _ = try await refreshStatusIfNeeded(req: req, song: song)

        guard song.status == "completed",
              let resultURLString = song.resultFileURL,
              let url = URL(string: resultURLString) else {
            throw Abort(.notFound, reason: "Converted audio not ready")
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as? HTTPURLResponse
        var vaporResponse = Response(
            status: HTTPResponseStatus(statusCode: httpResponse?.statusCode ?? 500),
            body: .init(data: data)
        )
        vaporResponse.headers.replaceOrAdd(name: .contentType, value: httpResponse?.value(forHTTPHeaderField: "Content-Type") ?? "audio/mpeg")
        return vaporResponse
    }

    private func findOwnedSong(req: Request) async throws -> ConvertedSong {
        let user = try await getUserFromPayload(req: req)
        let userID = try user.requireID()
        guard let convertedSongID = req.parameters.get("convertedSongID", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid convertedSongID")
        }
        guard let song = try await ConvertedSong.query(on: req.db)
            .filter(\.$id == convertedSongID)
            .filter(\.$user.$id == userID)
            .first() else {
            throw Abort(.notFound, reason: "Converted song not found")
        }
        return song
    }

    private func submitJobToBeamSVC(
        audioData: Data,
        filename: String,
        voiceId: String,
        voiceType: String?
    ) async throws -> BeamSVCAcceptedResponse {
        guard let url = URL(string: "\(beamSVCBaseURL)/ai-convert/voice-conversion") else {
            throw Abort(.internalServerError, reason: "Invalid BEAM_SVC_URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 1800

        var body = Data()
        appendFileField(&body, boundary: boundary, name: "source_audio", filename: filename, mimeType: "audio/mpeg", data: audioData)
        appendTextField(&body, boundary: boundary, name: "voiceId", value: voiceId)
        if let voiceType, !voiceType.isEmpty {
            appendTextField(&body, boundary: boundary, name: "voiceType", value: voiceType)
        }
        appendTextField(&body, boundary: boundary, name: "return_job", value: "true")
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw Abort(.badGateway, reason: String(data: data, encoding: .utf8) ?? "Beam SVC create job failed")
        }
        return try JSONDecoder().decode(BeamSVCAcceptedResponse.self, from: data)
    }

    private func refreshStatusIfNeeded(req: Request, song: ConvertedSong) async throws -> BeamSVCJobStatusResponse? {
        guard let jobId = song.beamSVCJobID,
              song.status == "queued" || song.status == "processing" else { return nil }

        let status = try await fetchBeamSVCStatus(jobId: jobId)
        song.status = status.status
        song.errorMessage = status.error
        if status.status == "completed" {
            song.resultFileURL = status.resultUrl
        }
        try await song.save(on: req.db)
        return status
    }

    private func fetchBeamSVCStatus(jobId: String) async throws -> BeamSVCJobStatusResponse {
        guard let url = URL(string: "\(beamSVCBaseURL)/ai-convert/jobs/\(jobId)") else {
            throw Abort(.internalServerError, reason: "Invalid BEAM_SVC_URL")
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw Abort(.badGateway, reason: "Beam SVC status fetch failed")
        }
        return try JSONDecoder().decode(BeamSVCJobStatusResponse.self, from: data)
    }

    private func makeResponseDTO(req: Request, song: ConvertedSong) throws -> ConvertedSongResponseDTO {
        ConvertedSongResponseDTO(
            id: try song.requireID(),
            sourceTrackId: song.sourceTrackID,
            sourcePlaybackUrl: song.sourcePlaybackURL,
            title: song.title,
            artistName: song.artistName,
            artworkUrl: song.artworkURL,
            voiceId: song.voiceID,
            voiceName: song.voiceName,
            voiceType: song.voiceType,
            status: song.status,
            jobId: song.beamSVCJobID,
            resultFileUrl: song.status == "completed" ? makeAudioProxyURL(req: req, songID: try song.requireID()) : nil,
            errorMessage: song.errorMessage,
            createdAt: song.createdAt,
            updatedAt: song.updatedAt
        )
    }

    private func makeAudioProxyURL(req: Request, songID: UUID) -> String {
        let scheme = req.headers.first(name: "X-Forwarded-Proto") ?? req.url.scheme ?? "http"
        let host = req.headers.first(name: .host) ?? "localhost"
        return "\(scheme)://\(host)/api/converted-songs/\(songID.uuidString)/audio"
    }

    private func makeSourceKey(sourceTrackId: String?, sourcePlaybackUrl: String?, title: String, artistName: String?) -> String {
        if let sourceTrackId, !sourceTrackId.isEmpty {
            return "track:\(sourceTrackId)"
        }
        if let sourcePlaybackUrl, !sourcePlaybackUrl.isEmpty {
            return "url:\(sourcePlaybackUrl)"
        }
        return "meta:\(title.lowercased())::\((artistName ?? "").lowercased())"
    }

    private func sanitizedFileName(title: String) -> String {
        title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }

    private func appendTextField(_ body: inout Data, boundary: String, name: String, value: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }

    private func appendFileField(_ body: inout Data, boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
    }
}
