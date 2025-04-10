import Vapor
import Fluent

struct AIPreferenceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let aiPreferences = routes.grouped("api", "ai-preferences")
        
        aiPreferences.get(":userId", use: getPreference)
        aiPreferences.post(use: createPreference)
        aiPreferences.put(":userId", use: updatePreference)
    }
    
    // 사용자의 AI 음악 선호도 조회
    func getPreference(req: Request) async throws -> AIPreference {
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        guard let preference = try await AIPreference.query(on: req.db)
            .filter(\.$userId == userId)
            .first() else {
            throw Abort(.notFound, reason: "Preference not found")
        }
        
        return preference
    }
    
    // 사용자의 AI 음악 선호도 생성
    func createPreference(req: Request) async throws -> AIPreference {
        let preference = try req.content.decode(AIPreference.self)
        try await preference.save(on: req.db)
        return preference
    }
    
    // 사용자의 AI 음악 선호도 업데이트
    func updatePreference(req: Request) async throws -> AIPreference {
        // 1. 요청에서 userId 가져오기 (기존과 동일)
        guard let userId = req.parameters.get("userId", as: UUID.self) else {
            throw Abort(.badRequest, reason: "Invalid user ID")
        }
        
        // 2. 요청 본문에서 업데이트할 데이터 가져오기 (기존과 동일)
        //    주의: AIPreference 모델 전체를 디코딩하는 것보다,
        //    업데이트할 값(enableAIMusic)만 포함하는 DTO(Data Transfer Object)를 만드는 것이 더 좋습니다.
        //    여기서는 간단하게 기존 AIPreference 모델을 사용한다고 가정합니다.
        let updatedPreferenceData = try req.content.decode(AIPreference.self) // enableAIMusic 값이 포함됨
        
        // 3. DB에서 기존 preference 찾기
        if let preference = try await AIPreference.query(on: req.db)
            .filter(\.$userId == userId)
            .first() {
            
            // --- 3-1. 기존 레코드가 있으면: 업데이트 ---
            preference.enableAIMusic = updatedPreferenceData.enableAIMusic // 요청된 값으로 업데이트
            try await preference.save(on: req.db) // 변경사항 저장
            
            // AI 음악 활성화 시 플레이리스트 추가 로직 (기존과 동일)
            if preference.enableAIMusic {
                // 플레이리스트에 이미 곡이 있는지 확인하는 로직 추가를 고려해보세요. (중복 방지)
                try await addAIMusicToPlaylist(req: req, userId: userId)
            }
            print("Updated AI preference for user: \(userId)") // 로그 추가
            return preference // 업데이트된 결과 반환
            
        } else {
            // --- 3-2. 기존 레코드가 없으면: 새로 생성 ---
            // 주의: AIPreference 모델에 id, userId, enableAIMusic 외 다른 필드가 있다면
            // 해당 필드도 초기화해주어야 할 수 있습니다.
            let newPreference = AIPreference(userId: userId, enableAIMusic: updatedPreferenceData.enableAIMusic)
            try await newPreference.save(on: req.db) // 새 레코드 저장
            
            // AI 음악 활성화 시 플레이리스트 추가 로직 (기존과 동일)
            if newPreference.enableAIMusic {
                try await addAIMusicToPlaylist(req: req, userId: userId)
            }
            print("Created new AI preference for user: \(userId)") // 로그 추가
            return newPreference // 새로 생성된 결과 반환
        }
    }
    
    private func addAIMusicToPlaylist(req: Request, userId: UUID) async throws {
        guard let playlist = try await UserPlaylist.query(on: req.db)
            .filter(\.$userID == userId)
            .first() else {
            throw Abort(.notFound, reason: "Playlist not found for user \(userId)")
        }

        let aiMusicSongs = try await getAIMusicSongs(req: req)

        for aiSong in aiMusicSongs {
            // Check if the AiSong has a valid song_id
            guard let songID = aiSong.$song.id else {
                req.logger.warning("AiSong \(aiSong.id?.uuidString ?? "N/A") has no associated Song")
                continue  // Skip this AiSong and continue with the next one
            }
            
            guard let relatedSong = try await Song.find(songID, on: req.db) else {
                req.logger.warning("Song with id \(songID) not found, referenced by AiSong \(aiSong.id?.uuidString ?? "N/A")")
                continue
            }
            
            let existingRelation = try await PlaylistSong.query(on: req.db)
                .filter(\.$playlist.$id == playlist.id!)
                .filter(\.$song.$id == relatedSong.id!)
                .first()

            if existingRelation == nil {
                // Add only if not already in playlist
                let playlistSong = try PlaylistSong(
                    playlist: playlist,
                    song: relatedSong
                )
                try await playlistSong.save(on: req.db)
                req.logger.info("Added song \(relatedSong.id?.uuidString ?? "N/A") to playlist \(playlist.id?.uuidString ?? "N/A")")
            } else {
                req.logger.info("Song \(relatedSong.id?.uuidString ?? "N/A") already exists in playlist \(playlist.id?.uuidString ?? "N/A")")
            }
        }
    }
    
    
    private func getNextPositionInPlaylist(req: Request, playlistId: UUID) async throws -> Int {
        let count = try await PlaylistSong.query(on: req.db)
            .filter(\.$playlist.$id == playlistId) // 수정됨
            .count()
        
        return count + 1
    }
    
    // 미리 준비된 AI 음악 목록 가져오기
    private func getAIMusicSongs(req: Request) async throws -> [AiSong] { // 반환 타입을 AiSong으로 변경
        req.logger.info("Fetching AI generated songs from 'AiSong' model...") // 로그 수정
        // 'Song' 모델 대신 'AiSong' 모델을 쿼리합니다.
        // 'AiSong' 모델에 isAIGenerated 필드가 정의되어 있다고 가정합니다.
        // 만약 AiSong 모델에 isAIGenerated 필드가 없다면, 이 필터링 없이 모든 AiSong을 가져오거나,
        // AiSong 모델/테이블에도 해당 필드를 추가해야 합니다.
        // 여기서는 AiSong 모델에도 해당 필드가 있다고 가정하고 진행합니다.
        return try await AiSong.query(on: req.db) // <--- AiSong 모델로 변경!
            // AiSong 모델에 isAIGenerated 필드가 없다면 아래 필터는 제거해야 합니다.
            // .filter(\.$isAIGenerated == true)
            .limit(3) // 적절한 수의 AI 음악만 추가 (기존과 동일)
            .all()
    }

}
