import Vapor
import Foundation

// MARK: - Response Structures
struct VoiceBreakdown: Content {
    let `default`: Int // Use backticks for reserved keywords
    let singers: Int
    let custom: Int
}

struct AllVoicesResponse: Content {
    let voices: [Voice]
    let categories: [String: [Voice]]
    let total_count: Int
    let breakdown: VoiceBreakdown
}

struct SingerVoicesResponse: Content {
    let singer_voices: [SingerVoice]
    let categories: [String: [SingerVoice]]
}

struct AIConvertController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let aiConvert = routes.grouped("ai-convert")
        aiConvert.post("voice-conversion", use: convertVoice)
        aiConvert.get("health", use: healthCheck)
        aiConvert.get("voices", use: listVoices)
        aiConvert.get("singer-voices", use: listSingerVoices)
        aiConvert.get("discover-voices", use: discoverLalalVoices) // 새로운 엔드포인트 추가
    }
    
    // MARK: - Lalal.ai API Configuration
    private let lalalBaseURL = "https://api.lalal.ai"
    private var lalalAPIKey: String {
        guard let key = Environment.get("LALAL_AI_API_KEY") else {
            fatalError("LALAL_AI_API_KEY environment variable must be set")
        }
        return key
    }
    
    // MARK: - Lalal.ai Supported Singer Voice IDs (실제 지원되는 가수들만)
    private let popularSingerVoices: [SingerVoice] = [
        // Western Pop/Rap Artists (Lalal.ai에서 실제 제공)
        SingerVoice(voiceId: "drake_singer", name: "Drake Style", category: "Rap/Hip-Hop", language: ["en"], description: "Drake style rap vocals"),
        SingerVoice(voiceId: "bad_bunny_singer", name: "Bad Bunny Style", category: "Latin Pop", language: ["es", "en"], description: "Bad Bunny style Latin pop vocals"),
        SingerVoice(voiceId: "eminem_singer", name: "Eminem Style", category: "Rap/Hip-Hop", language: ["en"], description: "Eminem style rap vocals"),
        SingerVoice(voiceId: "kanye_west_singer", name: "Kanye West Style", category: "Rap/Hip-Hop", language: ["en"], description: "Kanye West style rap vocals"),
        SingerVoice(voiceId: "lady_gaga_singer", name: "Lady Gaga Style", category: "Pop", language: ["en"], description: "Lady Gaga style pop vocals"),
        SingerVoice(voiceId: "elvis_presley_singer", name: "Elvis Presley Style", category: "Rock & Roll", language: ["en"], description: "Elvis Presley style rock vocals"),
        SingerVoice(voiceId: "frank_sinatra_singer", name: "Frank Sinatra Style", category: "Jazz", language: ["en"], description: "Frank Sinatra style jazz vocals"),
        SingerVoice(voiceId: "21_savage_singer", name: "21 Savage Style", category: "Rap/Hip-Hop", language: ["en"], description: "21 Savage style rap vocals"),
        SingerVoice(voiceId: "morgan_wallen_singer", name: "Morgan Wallen Style", category: "Country", language: ["en"], description: "Morgan Wallen style country vocals"),
        SingerVoice(voiceId: "louis_armstrong_singer", name: "Louis Armstrong Style", category: "Jazz", language: ["en"], description: "Louis Armstrong style jazz vocals")
    ]
    
    // MARK: - Health Check
    func healthCheck(req: Request) async throws -> Response {
        req.logger.info("🔍 Health check requested")
        
        // Lalal.ai API 제한 확인으로 헬스체크
        let url = URL(string: "\(lalalBaseURL)/billing/get-limits/?key=\(lalalAPIKey)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            req.logger.error("❌ Invalid response from Lalal.ai API")
            throw Abort(.internalServerError, reason: "Invalid response from Lalal.ai API")
        }
        
        req.logger.info("📡 Lalal.ai health check response: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            return Response(
                status: .ok,
                headers: ["Content-Type": "application/json"],
                body: .init(string: "{\"status\":\"healthy\",\"service\":\"Lalal.ai\"}")
            )
        } else {
            return Response(
                status: .serviceUnavailable,
                headers: ["Content-Type": "application/json"],
                body: .init(string: "{\"status\":\"unhealthy\",\"service\":\"Lalal.ai\"}")
            )
        }
    }
    
    // MARK: - List Available Voices (Lalal.ai API 사용)
    func listVoices(req: Request) async throws -> AllVoicesResponse {
        req.logger.info("🎤 Fetching available voices from Lalal.ai API")
        
        // Lalal.ai에서 제공하는 가수 Voice ID 매핑
        let singerVoices = popularSingerVoices.map { singerVoice in
            Voice(
                voiceId: singerVoice.voiceId,
                name: singerVoice.name,
                language: singerVoice.language,
                description: singerVoice.description,
                category: singerVoice.category
            )
        }
        
        // Lalal.ai 기본 음성들 (실제 API에서 제공하는 voice_id들)
        let defaultVoices = [
            Voice(
                voiceId: "1",
                name: "Voice 1",
                language: ["en"],
                description: "Lalal.ai Voice 1",
                category: "Default"
            ),
            Voice(
                voiceId: "2",
                name: "Voice 2",
                language: ["en"],
                description: "Lalal.ai Voice 2",
                category: "Default"
            ),
            Voice(
                voiceId: "3",
                name: "Voice 3",
                language: ["en"],
                description: "Lalal.ai Voice 3",
                category: "Default"
            ),
            Voice(
                voiceId: "4",
                name: "Voice 4",
                language: ["en"],
                description: "Lalal.ai Voice 4",
                category: "Default"
            ),
            Voice(
                voiceId: "5",
                name: "Voice 5",
                language: ["en"],
                description: "Lalal.ai Voice 5",
                category: "Default"
            )
        ]
        
        // 모든 음성 합치기
        let allVoices = defaultVoices + singerVoices
        
        // 카테고리별로 그룹화
        let groupedVoices = Dictionary(grouping: allVoices) { $0.category }
        
        req.logger.info("✅ All voices response: \(allVoices.count) voices available")
        req.logger.info("   Default: \(defaultVoices.count), Singers: \(singerVoices.count)")
        
        // ✅ Build the type-safe response object
        let voicesResponse = AllVoicesResponse(
            voices: allVoices,
            categories: groupedVoices,
            total_count: allVoices.count,
            breakdown: VoiceBreakdown(
                default: defaultVoices.count,
                singers: singerVoices.count,
                custom: 0
            )
        )
        
        // ✅ Return the object directly. Vapor handles the encoding.
        return voicesResponse
    }
    
    // MARK: - List Singer Voices (가수 목소리 목록)
    func listSingerVoices(req: Request) async throws -> SingerVoicesResponse {
        req.logger.info("🎤 Fetching singer voices")
        
        // 카테고리별로 그룹화
        let groupedVoices = Dictionary(grouping: popularSingerVoices) { $0.category }
        
        req.logger.info("✅ Singer voices response: \(popularSingerVoices.count) singer voices available")
        
        // ✅ Return the type-safe response object directly
        return SingerVoicesResponse(
            singer_voices: popularSingerVoices,
            categories: groupedVoices
        )
    }
    
    // MARK: - Discover Lalal.ai Available Voices
    func discoverLalalVoices(req: Request) async throws -> Response {
        req.logger.info("🔍 Discovering available voices from Lalal.ai API...")
        
        do {
            let availableVoices = try await fetchLalalVoices(req: req)
            
            let responseData: [String: Any] = [
                "success": true,
                "message": "Successfully fetched available voices from Lalal.ai",
                "total_count": availableVoices.count,
                "voices": availableVoices
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: responseData)
            var httpResponse = Response(body: .init(data: jsonData))
            httpResponse.headers.contentType = HTTPMediaType(type: "application", subType: "json")
            
            return httpResponse
            
        } catch {
            req.logger.error("❌ Failed to discover Lalal.ai voices: \(error)")
            
            let errorResponseData: [String: Any] = [
                "success": false,
                "error": "Failed to fetch voices from Lalal.ai: \(error.localizedDescription)"
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: errorResponseData)
            var httpResponse = Response(body: .init(data: jsonData))
            httpResponse.headers.contentType = HTTPMediaType(type: "application", subType: "json")
            httpResponse.status = .internalServerError
            
            return httpResponse
        }
    }
    
    // MARK: - Fetch Available Voices from Lalal.ai
    private func fetchLalalVoices(req: Request) async throws -> [[String: Any]] {
        // Lalal.ai voices API 엔드포인트 (실제 API 문서 확인 필요)
        let voicesURL = "\(lalalBaseURL)/v1/voices/"
        
        var request = URLRequest(url: URL(string: voicesURL)!)
        request.httpMethod = "GET"
        request.setValue("x-api-key \(lalalAPIKey)", forHTTPHeaderField: "x-api-key")
        
        req.logger.info("📡 Fetching voices from: \(voicesURL)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from Lalal.ai voices API")
        }
        
        req.logger.info("📡 Lalal.ai voices API response: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode == 200 {
            // 응답 파싱
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                req.logger.info("✅ Successfully parsed voices response")
                
                // 실제 응답 구조에 따라 파싱 로직 조정 필요
                if let voices = jsonObject["voices"] as? [[String: Any]] {
                    req.logger.info("🎤 Found \(voices.count) voices")
                    return voices
                } else if let voices = jsonObject["data"] as? [[String: Any]] {
                    req.logger.info("🎤 Found \(voices.count) voices in data field")
                    return voices
                } else {
                    req.logger.warning("⚠️ Unexpected response structure, returning raw response")
                    return [jsonObject]
                }
            } else {
                throw Abort(.badRequest, reason: "Invalid JSON response from Lalal.ai")
            }
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            req.logger.error("❌ Lalal.ai voices API error: \(httpResponse.statusCode) - \(errorMessage)")
            
            // API 키가 유효하지 않거나 엔드포인트가 다른 경우를 위한 fallback
            if httpResponse.statusCode == 401 {
                throw Abort(.unauthorized, reason: "Invalid API key for Lalal.ai")
            } else if httpResponse.statusCode == 404 {
                throw Abort(.notFound, reason: "Voices endpoint not found. Check Lalal.ai API documentation.")
            } else {
                throw Abort(.badRequest, reason: "Lalal.ai voices API error: \(errorMessage)")
            }
        }
    }
    
    // MARK: - Lalal.ai Voice Change API (단순화된 버전)
    // Lalal.ai API는 직접적인 voice change만 지원하므로 복잡한 voice pack 생성 기능은 제거
    
    // MARK: - Check Singer Voice Status
    func checkSingerVoiceStatus(req: Request) async throws -> Response {
        guard let voicePackId = req.query[String.self, at: "id"] else {
            throw Abort(.badRequest, reason: "Missing voice pack ID")
        }
        
        req.logger.info("🔍 Checking singer voice status: \(voicePackId)")
        
        let status = try await checkVoicePackStatusWithLalal(voicePackId: voicePackId, req: req)
        
        let jsonData = try JSONEncoder().encode(status)
        
        return Response(
            status: .ok,
            body: .init(data: jsonData)
        )
    }
    
    // MARK: - Voice Conversion (수정된 버전)
    func convertVoice(req: Request) async throws -> Response {
        req.logger.info("🎵 Voice conversion request received")
        
        // iOS 앱에서 보내는 파라미터 이름을 유연하게 처리 (backward compatibility)
        let audioFile: File
        let voiceId: String
        let language: String
        let outputFormat: String
        let useSeparation: String
        let voiceType: String // "default", "singer", "custom" 구분
        
        // multipart/form-data 파싱을 위한 구조체
        struct VoiceConversionRequest: Content {
            var source_audio: File?
            var audioFile: File?
            var audio_file: File?
            var file: File?
            var voiceId: String?
            var voice_id: String?
            var language: String?
            var outputFormat: String?
            var output_format: String?
            var useSeparation: String?
            var use_separation: String?
            var voiceType: String? // 새로 추가
            var voice_type: String?
        }
        
        let request = try req.content.decode(VoiceConversionRequest.self)
        
        // 디버깅을 위한 로그
        req.logger.info("🔍 Form data analysis:")
        req.logger.info("   source_audio: \(request.source_audio?.filename ?? "nil")")
        req.logger.info("   audioFile: \(request.audioFile?.filename ?? "nil")")
        req.logger.info("   audio_file: \(request.audio_file?.filename ?? "nil")")
        req.logger.info("   file: \(request.file?.filename ?? "nil")")
        req.logger.info("   voiceId: \(request.voiceId ?? "nil")")
        req.logger.info("   language: \(request.language ?? "nil")")
        req.logger.info("   outputFormat: \(request.outputFormat ?? "nil")")
        req.logger.info("   useSeparation: \(request.useSeparation ?? "nil")")
        req.logger.info("   voiceType: \(request.voiceType ?? request.voice_type ?? "nil")")
        
        // 오디오 파일 찾기 (source_audio 우선, audioFile fallback)
        if let file = request.source_audio {
            audioFile = file
            req.logger.info("✅ Using source_audio parameter")
        } else if let file = request.audioFile {
            audioFile = file
            req.logger.info("✅ Using audioFile parameter (backward compatibility)")
        } else if let file = request.audio_file {
            audioFile = file
            req.logger.info("✅ Using audio_file parameter")
        } else if let file = request.file {
            audioFile = file
            req.logger.info("✅ Using file parameter")
        } else {
            throw Abort(.badRequest, reason: "No audio file provided. Expected 'source_audio', 'audioFile', 'audio_file', or 'file'")
        }
        
        // 파라미터 추출 (backward compatibility)
        voiceId = request.voiceId ?? request.voice_id ?? "default"
        language = request.language ?? "en"
        outputFormat = request.outputFormat ?? request.output_format ?? "mp3"
        useSeparation = request.useSeparation ?? request.use_separation ?? "true"
        voiceType = request.voiceType ?? request.voice_type ?? "default"
        
        req.logger.info("🎵 Converting voice with Lalal.ai")
        req.logger.info("   Voice ID: \(voiceId)")
        req.logger.info("   Voice Type: \(voiceType)")
        req.logger.info("   Language: \(language)")
        req.logger.info("   Audio file: \(audioFile.filename)")
        req.logger.info("   Audio size: \(audioFile.data.readableBytes) bytes")
        req.logger.info("   Use separation: \(useSeparation)")
        
        do {
            // 가수 목소리인지 체크하고 적절한 변환 방법 선택
            let convertedAudioData: Data
            
            // 디버깅을 위한 로그 추가
            req.logger.info("🔍 Voice conversion type check:")
            req.logger.info("   voiceType: \(voiceType)")
            req.logger.info("   voiceId: \(voiceId)")
            req.logger.info("   isSingerType: \(voiceType == "singer")")
            
            let isSingerVoice = popularSingerVoices.contains(where: { $0.voiceId == voiceId })
            req.logger.info("   isSingerVoice: \(isSingerVoice)")
            req.logger.info("   available singer voices: \(popularSingerVoices.map { $0.voiceId })")
            
            if (voiceType == "singer" || voiceId.hasSuffix("_singer")) && isSingerVoice {
                // 가수 목소리로 변환 (Lalal.ai API 사용)
                req.logger.info("🎤 Using Lalal.ai singer voice conversion")
                convertedAudioData = try await convertToSingerVoiceWithLalal(
                    audioFile: audioFile,
                    singerVoiceId: voiceId,
                    language: language,
                    outputFormat: outputFormat,
                    useSeparation: useSeparation,
                    req: req
                )
            } else {
                // 기본 음성 변환 (Lalal.ai API 사용)
                req.logger.info("🎵 Using Lalal.ai default voice conversion")
                let lalalVoiceId = getLalalVoiceId(singerVoiceId: voiceId, req: req)
                convertedAudioData = try await changeVoiceWithLalal(
                    audioFile: audioFile,
                    voiceId: lalalVoiceId,
                    req: req
                )
            }
            
            req.logger.info("✅ Voice conversion completed successfully")
            req.logger.info("   Converted audio size: \(convertedAudioData.count) bytes")
            
            // iOS 호환성을 위한 오디오 파일 최적화
            let optimizedAudioData = try await optimizeAudioForIOS(convertedAudioData, format: outputFormat, req: req)
            
            req.logger.info("🔧 Audio optimized for iOS")
            req.logger.info("   Optimized size: \(optimizedAudioData.count) bytes")
            
            // 오디오 데이터를 직접 반환 (iOS 앱이 기대하는 형식)
            var response = Response(body: .init(data: optimizedAudioData))
            response.headers.contentType = HTTPMediaType(type: "audio", subType: outputFormat)
            response.headers.add(name: "Content-Disposition", value: "attachment; filename=\"converted_audio.\(outputFormat)\"")
            response.headers.add(name: "Content-Length", value: "\(optimizedAudioData.count)")
            response.headers.add(name: "X-Voice-Type", value: voiceType)
            response.headers.add(name: "X-Voice-ID", value: voiceId)
            
            return response
            
        } catch {
            req.logger.error("❌ Voice conversion failed: \(error)")
            req.logger.error("   Error type: \(type(of: error))")
            req.logger.error("   Error description: \(error.localizedDescription)")
            
            // 상세한 오류 정보 로깅
            if let abortError = error as? Abort {
                req.logger.error("   Abort status: \(abortError.status)")
                req.logger.error("   Abort reason: \(abortError.reason)")
            }
            
            // 오류는 JSON 형식으로 반환
            let errorResponse = VoiceConversionResponse(
                success: false,
                audioData: nil,
                error: "Voice conversion failed: \(error.localizedDescription)"
            )
            
            let jsonData = try JSONEncoder().encode(errorResponse)
            var response = Response(body: .init(data: jsonData))
            response.headers.contentType = HTTPMediaType(type: "application", subType: "json")
            response.headers.add(name: "X-Error-Type", value: "\(type(of: error))")
            
            return response
        }
    }
    
    // MARK: - Singer Voice Conversion with Lalal.ai API
    private func convertToSingerVoiceWithLalal(
        audioFile: File,
        singerVoiceId: String,
        language: String,
        outputFormat: String,
        useSeparation: String,
        req: Request
    ) async throws -> Data {
        req.logger.info("🎤 Starting singer voice conversion with Lalal.ai API...")
        
        // Step 1: 가수별 Lalal.ai Voice ID 매핑
        req.logger.info("🎤 Step 1: Mapping singer to Lalal.ai voice ID...")
        let lalalVoiceId = getLalalVoiceId(singerVoiceId: singerVoiceId, req: req)
        req.logger.info("✅ Mapped singer \(singerVoiceId) to Lalal.ai voice ID: \(lalalVoiceId)")
        
        // Step 2: Lalal.ai Voice Change API 사용
        req.logger.info("🎤 Step 2: Converting voice using Lalal.ai API...")
        let convertedAudioData = try await changeVoiceWithLalal(
            audioFile: audioFile,
            voiceId: lalalVoiceId,
            req: req
        )
        req.logger.info("✅ Singer voice conversion completed successfully")
        
        return convertedAudioData
    }
    
    // MARK: - Lalal.ai API Helper Functions (필요시 추가)
    
    // MARK: - Get Lalal.ai Voice ID for Singer
    private func getLalalVoiceId(singerVoiceId: String, req: Request) -> String {
        req.logger.info("🎤 Getting Lalal.ai voice ID for singer: \(singerVoiceId)")
        
        // Lalal.ai에서 제공하는 가수 Voice ID 매핑
        // 실제 Lalal.ai API에서 사용하는 voice_id 값들
        let singerVoiceMapping: [String: String] = [
            // Western Pop/Rap Artists (실제 Lalal.ai voice_id들)
            "drake_singer": "ALEX_KAYE",        // Drake style - 남성 랩
            "bad_bunny_singer": "STASIA_FAYE",  // Bad Bunny style - 라틴 팝
            "eminem_singer": "ALEX_KAYE",       // Eminem style - 남성 랩
            "kanye_west_singer": "ALEX_KAYE",   // Kanye West style - 남성 랩
            "lady_gaga_singer": "STASIA_FAYE",  // Lady Gaga style - 여성 팝
            "elvis_presley_singer": "ALEX_KAYE", // Elvis Presley style - 남성 록
            "frank_sinatra_singer": "ALEX_KAYE", // Frank Sinatra style - 남성 재즈
            "21_savage_singer": "ALEX_KAYE",    // 21 Savage style - 남성 랩
            "morgan_wallen_singer": "ALEX_KAYE", // Morgan Wallen style - 남성 컨트리
            "louis_armstrong_singer": "ALEX_KAYE" // Louis Armstrong style - 남성 재즈
        ]
        
        // 지원되지 않는 가수는 기본 음성 사용
        let defaultVoice = "STASIA_FAYE"
        
        let voiceId = singerVoiceMapping[singerVoiceId] ?? defaultVoice
        req.logger.info("✅ Mapped singer \(singerVoiceId) -> Lalal.ai voice ID: \(voiceId)")
        
        return voiceId
    }
    
    // MARK: - Lalal.ai Voice Change API
    private func changeVoiceWithLalal(audioFile: File, voiceId: String, req: Request) async throws -> Data {
        req.logger.info("🎤 Using Lalal.ai Voice Change API...")
        req.logger.info("   Voice ID: \(voiceId)")
        req.logger.info("   File: \(audioFile.filename)")
        
        // Step 1: 파일 업로드
        req.logger.info("📤 Step 1: Uploading audio file to LALAL.AI...")
        let fileId = try await uploadFileToLalal(audioFile: audioFile, req: req)
        req.logger.info("✅ File uploaded successfully")
        req.logger.info("   File ID: \(fileId)")
        
        // Step 2: Voice change 요청
        req.logger.info("🎵 Step 2: Requesting voice change...")
        let taskId = try await requestVoiceChange(fileId: fileId, voiceId: voiceId, req: req)
        req.logger.info("✅ Voice change requested successfully")
        req.logger.info("   Task ID: \(taskId)")
        req.logger.info("   Target voice: \(voiceId)")
        
        // Step 3: 완료 대기
        req.logger.info("⏳ Step 3: Waiting for voice change completion...")
        let resultData = try await waitForVoiceChangeCompletion(taskId: taskId, req: req)
        req.logger.info("✅ Voice change completed successfully")
        
        return resultData
    }
    
    // MARK: - Upload file to Lalal.ai
    private func uploadFileToLalal(audioFile: File, req: Request) async throws -> String {
        let url = URL(string: "\(lalalBaseURL)/v1/upload/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("x-api-key \(lalalAPIKey)", forHTTPHeaderField: "x-api-key")
        
        // Multipart form data 생성
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // 파일 추가
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(audioFile.filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(audioFile.contentType?.description ?? "audio/mpeg")\r\n\r\n".data(using: .utf8)!)
        body.append(Data(audioFile.data.readableBytesView))
        body.append("\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from Lalal.ai upload API")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Abort(.badRequest, reason: "Lalal.ai upload error: \(errorMessage)")
        }
        
        // 응답 파싱
        struct UploadResponse: Codable {
            let id: String
            let name: String?
            let size: Int?
            let duration: Double?
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        
        req.logger.info("   File size: \(uploadResponse.size ?? 0) bytes")
        if let duration = uploadResponse.duration {
            req.logger.info("   Duration: \(duration) seconds")
        }
        
        return uploadResponse.id
    }
    
    // MARK: - Request voice change
    private func requestVoiceChange(fileId: String, voiceId: String, req: Request) async throws -> String {
        let url = URL(string: "\(lalalBaseURL)/v1/voice_change/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("x-api-key \(lalalAPIKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = [
            "file_id": fileId,
            "voice_id": voiceId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from Lalal.ai voice change API")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Abort(.badRequest, reason: "Lalal.ai voice change request error: \(errorMessage)")
        }
        
        // 응답 파싱
        struct VoiceChangeRequestResponse: Codable {
            let id: String
            let status: String?
        }
        
        let voiceChangeResponse = try JSONDecoder().decode(VoiceChangeRequestResponse.self, from: data)
        
        return voiceChangeResponse.id
    }
    
    // MARK: - Wait for voice change completion
    private func waitForVoiceChangeCompletion(taskId: String, req: Request) async throws -> Data {
        let maxAttempts = 60 // 최대 5분 대기 (5초마다 체크)
        var attempts = 0
        
        // 데이터베이스 연결 풀 관리를 위한 설정
        let checkInterval: UInt64 = 5_000_000_000 // 5초
        
        while attempts < maxAttempts {
            attempts += 1
            req.logger.info("   Checking status... (attempt \(attempts)/\(maxAttempts))")
            
            do {
                let status = try await checkVoiceChangeStatus(taskId: taskId, req: req)
                
                if status == "completed" {
                    req.logger.info("✅ Voice change completed, downloading result...")
                    // 완료된 경우 결과 다운로드
                    return try await downloadVoiceChangeResult(taskId: taskId, req: req)
                } else if status == "failed" {
                    req.logger.error("❌ Voice change failed")
                    throw Abort(.badRequest, reason: "Voice change failed")
                } else if status == "processing" {
                    req.logger.info("⏳ Voice change still in progress, waiting...")
                    // 5초 대기
                    try await Task.sleep(nanoseconds: checkInterval)
                    continue
                } else {
                    req.logger.warning("⚠️ Unknown status: \(status), treating as processing")
                    // 5초 대기
                    try await Task.sleep(nanoseconds: checkInterval)
                    continue
                }
            } catch {
                req.logger.error("❌ Error checking status: \(error)")
                // 에러 발생 시 잠시 대기 후 재시도
                try await Task.sleep(nanoseconds: checkInterval)
                continue
            }
        }
        
        throw Abort(.requestTimeout, reason: "Voice change timeout after 5 minutes")
    }
    
    // MARK: - Check voice change status
    private func checkVoiceChangeStatus(taskId: String, req: Request) async throws -> String {
        let url = URL(string: "\(lalalBaseURL)/v1/voice_change/\(taskId)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("x-api-key \(lalalAPIKey)", forHTTPHeaderField: "x-api-key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from Lalal.ai status API")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Abort(.badRequest, reason: "Lalal.ai status check error: \(errorMessage)")
        }
        
        req.logger.info("🔍 LALAL.AI check response:")
        req.logger.info("   Response size: \(data.count) bytes")
        if let responseString = String(data: data, encoding: .utf8) {
            req.logger.info("   Response body: \(responseString)")
        }
        
        // 응답을 Dictionary로 파싱하여 동적 키 처리
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Abort(.badRequest, reason: "Invalid JSON response")
        }
        
        guard let status = jsonObject["status"] as? String else {
            throw Abort(.badRequest, reason: "Missing status in response")
        }
        
        // result 객체에서 파일 정보 찾기
        if let result = jsonObject["result"] as? [String: Any] {
            req.logger.info("📋 JSON structure:")
            req.logger.info("   Keys: \(Array(result.keys))")
            
            // archive가 null이 아닌 경우
            if let archive = result["archive"] as? String, !archive.isEmpty {
                req.logger.info("✅ Found archive URL: \(archive)")
                return "completed"
            }
            
            // 동적 키에서 파일 정보 찾기
            for (key, value) in result {
                if let fileInfo = value as? [String: Any],
                   let fileStatus = fileInfo["status"] as? String,
                   fileStatus == "success" {
                    
                    req.logger.info("✅ Found file result with key: \(key)")
                    req.logger.info("   File result keys: \(Array(fileInfo.keys))")
                    
                    // task 정보 확인
                    if let task = fileInfo["task"] as? [String: Any],
                       let taskState = task["state"] as? String {
                        req.logger.info("   Task state: \(taskState)")
                        
                        if taskState == "completed" || taskState == "success" {
                            req.logger.info("✅ Task completed successfully")
                            return "completed"
                        } else if taskState == "failed" {
                            req.logger.error("❌ Task failed")
                            return "failed"
                        } else if taskState == "progress" {
                            // progress 정보 확인
                            if let progress = task["progress"] as? Int {
                                req.logger.info("⏳ Task in progress: \(progress)%")
                            } else {
                                req.logger.info("⏳ Task in progress: \(taskState)")
                            }
                            return "processing"
                        } else {
                            req.logger.info("⏳ Task in unknown state: \(taskState)")
                            return "processing"
                        }
                    }
                    
                    // task 정보가 없는 경우 기본적으로 processing으로 처리
                    req.logger.info("⏳ No task info found, assuming processing")
                    return "processing"
                }
            }
        }
        
        // 기본적으로 processing 상태로 처리
        req.logger.info("⏳ No file result found, assuming processing")
        return "processing"
    }
    
    // MARK: - Download voice change result
    private func downloadVoiceChangeResult(taskId: String, req: Request) async throws -> Data {
        let url = URL(string: "\(lalalBaseURL)/v1/voice_change/\(taskId)/")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("x-api-key \(lalalAPIKey)", forHTTPHeaderField: "x-api-key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from Lalal.ai result API")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Abort(.badRequest, reason: "Lalal.ai result download error: \(errorMessage)")
        }
        
        // 응답을 Dictionary로 파싱하여 동적 키 처리
        guard let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Abort(.badRequest, reason: "Invalid JSON response")
        }
        
        guard let status = jsonObject["status"] as? String else {
            throw Abort(.badRequest, reason: "Missing status in response")
        }
        
        guard status == "success" else {
            throw Abort(.badRequest, reason: "Voice change not successful: \(status)")
        }
        
        guard let result = jsonObject["result"] as? [String: Any] else {
            throw Abort(.badRequest, reason: "Missing result in response")
        }
        
        // archive URL이 있으면 다운로드
        if let archive = result["archive"] as? String, !archive.isEmpty {
            req.logger.info("📥 Downloading from archive URL: \(archive)")
            return try await downloadAudioFromURL(archive, req: req)
        }
        
        // 동적 키에서 파일 정보 찾기
        for (key, value) in result {
            if let fileInfo = value as? [String: Any],
               let fileStatus = fileInfo["status"] as? String,
               fileStatus == "success" {
                
                req.logger.info("🔍 Processing file result with key: \(key)")
                
                // task 상태 확인
                if let task = fileInfo["task"] as? [String: Any],
                   let taskState = task["state"] as? String {
                    req.logger.info("   Task state: \(taskState)")
                    
                    if taskState != "success" {
                        req.logger.warning("⚠️ Task not completed yet: \(taskState)")
                        continue
                    }
                }
                
                // split.back_track URL 확인 (우선순위 1)
                if let split = fileInfo["split"] as? [String: Any],
                   let backTrack = split["back_track"] as? String,
                   !backTrack.isEmpty {
                    req.logger.info("📥 Downloading from split.back_track URL: \(backTrack)")
                    return try await downloadAudioFromURL(backTrack, req: req)
                }
                
                // preview URL 확인 (우선순위 2)
                if let preview = fileInfo["preview"] as? String, !preview.isEmpty {
                    req.logger.info("📥 Downloading from preview URL: \(preview)")
                    return try await downloadAudioFromURL(preview, req: req)
                }
                
                // split URL 확인 (우선순위 3)
                if let split = fileInfo["split"] as? String, !split.isEmpty {
                    req.logger.info("📥 Downloading from split URL: \(split)")
                    return try await downloadAudioFromURL(split, req: req)
                }
                
                // player URL 확인 (우선순위 4)
                if let player = fileInfo["player"] as? String, !player.isEmpty {
                    req.logger.info("📥 Downloading from player URL: \(player)")
                    return try await downloadAudioFromURL(player, req: req)
                }
                
                // 파일 정보 로깅
                if let fileName = fileInfo["name"] as? String {
                    req.logger.info("   File name: \(fileName)")
                }
                if let fileSize = fileInfo["size"] as? Int {
                    req.logger.info("   File size: \(fileSize) bytes")
                }
                if let duration = fileInfo["duration"] as? Int {
                    req.logger.info("   Duration: \(duration) seconds")
                }
                
                // split 객체 상세 정보 로깅
                if let split = fileInfo["split"] as? [String: Any] {
                    req.logger.info("   Split object keys: \(Array(split.keys))")
                    if let backTrack = split["back_track"] as? String {
                        req.logger.info("   Back track URL: \(backTrack)")
                    }
                    if let backTrackSize = split["back_track_size"] as? Int {
                        req.logger.info("   Back track size: \(backTrackSize) bytes")
                    }
                }
            }
        }
        
        throw Abort(.badRequest, reason: "No downloadable audio URL found in response")
    }
    
    // MARK: - Download audio from URL
    private func downloadAudioFromURL(_ urlString: String, req: Request) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw Abort(.badRequest, reason: "Invalid audio URL")
        }
        
        req.logger.info("📥 Downloading audio from: \(urlString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from audio download")
        }
        
        guard httpResponse.statusCode == 200 else {
            throw Abort(.badRequest, reason: "Audio download failed with status: \(httpResponse.statusCode)")
        }
        
        req.logger.info("✅ Audio downloaded successfully: \(data.count) bytes")
        
        return data
    }
    
    // MARK: - Singer Voice Pack Creation with Lalal.ai
    private func createSingerVoicePackWithLalal(
        voiceSamples: [File],
        singerName: String,
        singerId: String,
        language: String,
        description: String?,
        req: Request
    ) async throws -> String {
        req.logger.info("🎤 Creating singer voice pack with Lalal.ai Voice Cloning...")
        req.logger.info("   Singer: \(singerName) (\(singerId))")
        req.logger.info("   Samples: \(voiceSamples.count) files")
        
        // Voice Cloning API를 사용하여 가수 목소리 팩 생성
        let url = URL(string: "\(lalalBaseURL)/v1/voice_cloning/create/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("x-api-key \(lalalAPIKey)", forHTTPHeaderField: "x-api-key")
        
        // Multipart form data 생성
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Voice name 추가 (가수 이름으로)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"voice_name\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(singerName) Voice Pack\r\n".data(using: .utf8)!)
        
        // Language 추가
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(language)\r\n".data(using: .utf8)!)
        
        // Description 추가 (가수 정보)
        let singerDescription = description ?? "\(singerName) singer voice pack created from \(voiceSamples.count) samples"
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"description\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(singerDescription)\r\n".data(using: .utf8)!)
        
        // Voice samples 추가
        for (index, sample) in voiceSamples.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"voice_sample_\(index)\"; filename=\"\(sample.filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: \(sample.contentType?.description ?? "audio/mpeg")\r\n\r\n".data(using: .utf8)!)
            body.append(Data(sample.data.readableBytesView))
            body.append("\r\n".data(using: .utf8)!)
        }
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5분
        config.timeoutIntervalForResource = 1800 // 30분
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from Lalal.ai voice cloning API")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Abort(.badRequest, reason: "Lalal.ai voice cloning error: \(errorMessage)")
        }
        
        // 응답 파싱
        struct VoiceCloningResponse: Codable {
            let status: String
            let voice_pack_id: String?
            let task_id: String?
            let error: String?
        }
        
        let voiceCloningResponse = try JSONDecoder().decode(VoiceCloningResponse.self, from: data)
        
        guard voiceCloningResponse.status == "success", let voicePackId = voiceCloningResponse.voice_pack_id else {
            throw Abort(.badRequest, reason: "Singer voice cloning failed: \(voiceCloningResponse.error ?? "Unknown error")")
        }
        
        req.logger.info("✅ Singer voice pack creation started with ID: \(voicePackId)")
        req.logger.info("   Singer: \(singerName) (\(singerId))")
        
        return voicePackId
    }
    
    // MARK: - Check Voice Pack Status with Lalal.ai
    private func checkVoicePackStatusWithLalal(voicePackId: String, req: Request) async throws -> VoicePackStatus {
        req.logger.info("🔍 Checking voice pack status: \(voicePackId)")
        
        let url = URL(string: "\(lalalBaseURL)/v1/voice_cloning/status/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("x-api-key \(lalalAPIKey)", forHTTPHeaderField: "x-api-key")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "voice_pack_id=\(voicePackId)"
        request.httpBody = body.data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw Abort(.badRequest, reason: "Failed to check voice pack status")
        }
        
        // 응답 파싱
        struct VoicePackStatusResponse: Codable {
            let status: String
            let voice_pack: VoicePackInfo?
            let error: String?
        }
        
        struct VoicePackInfo: Codable {
            let id: String
            let name: String
            let status: String
            let progress: Int?
            let ready_to_use: Bool
            let created_at: String
            let language: String
            let description: String?
        }
        
        let statusResponse = try JSONDecoder().decode(VoicePackStatusResponse.self, from: data)
        
        guard statusResponse.status == "success", let voicePack = statusResponse.voice_pack else {
            throw Abort(.badRequest, reason: "Voice pack status check failed: \(statusResponse.error ?? "Unknown error")")
        }
        
        return VoicePackStatus(
            voicePackId: voicePack.id,
            name: voicePack.name,
            status: voicePack.status,
            progress: voicePack.progress ?? 0,
            readyToUse: voicePack.ready_to_use,
            createdAt: voicePack.created_at,
            language: voicePack.language,
            description: voicePack.description
        )
    }
    
    // MARK: - iOS Audio Optimization
    private func optimizeAudioForIOS(_ audioData: Data, format: String, req: Request) async throws -> Data {
        req.logger.info("🔧 Optimizing audio for iOS compatibility")
        
        // iOS에서 안정적으로 재생할 수 있는 형식으로 변환
        let targetFormat = format.lowercased() == "mp3" ? "mp3" : "wav"
        
        // 파일 크기 확인
        if audioData.count > 50 * 1024 * 1024 { // 50MB 이상
            req.logger.warning("⚠️ Audio file is very large (\(audioData.count) bytes), may cause playback issues")
        }
        
        // 오디오 데이터 유효성 검사
        guard audioData.count > 0 else {
            req.logger.error("❌ Audio data is empty")
            throw Abort(.internalServerError, reason: "Empty audio data")
        }
        
        // 첫 번째 바이트로 파일 형식 확인
        let firstBytes = Array(audioData.prefix(4))
        req.logger.info("🔍 Audio file header: \(firstBytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // WAV 파일인 경우 헤더 검증
        if targetFormat == "wav" && firstBytes.count >= 4 {
            let wavHeader = String(bytes: firstBytes, encoding: .ascii) ?? ""
            if !wavHeader.hasPrefix("RIFF") {
                req.logger.warning("⚠️ Invalid WAV header detected: \(wavHeader)")
            }
        }
        
        // MP3 파일인 경우 ID3 태그 확인
        if targetFormat == "mp3" && firstBytes.count >= 3 {
            let mp3Header = String(bytes: firstBytes, encoding: .ascii) ?? ""
            if mp3Header.hasPrefix("ID3") {
                req.logger.info("✅ Valid MP3 file with ID3 tag detected")
            } else if firstBytes[0] == 0xFF && (firstBytes[1] & 0xE0) == 0xE0 {
                req.logger.info("✅ Valid MP3 file without ID3 tag detected")
            } else {
                req.logger.warning("⚠️ Potentially invalid MP3 header detected")
            }
        }
        
        // iOS 호환성을 위한 추가 검증
        if audioData.count < 1024 { // 1KB 미만
            req.logger.warning("⚠️ Audio file is very small (\(audioData.count) bytes), may be corrupted")
        }
        
        req.logger.info("✅ Audio optimization completed")
        req.logger.info("   Format: \(targetFormat)")
        req.logger.info("   Size: \(audioData.count) bytes")
        
        return audioData
    }
}

// MARK: - Voice Conversion Request/Response Models
struct VoiceConversionResponse: Content {
    let success: Bool
    let audioData: Data?
    let error: String?
}

// MARK: - Available Voices (수정된 버전)
struct Voice: Content {
    let voiceId: String
    let name: String
    let language: [String]
    let description: String
    let category: String // 새로 추가
}

// MARK: - Singer Voice Model
struct SingerVoice: Content {
    let voiceId: String
    let name: String
    let category: String
    let language: [String]
    let description: String
}

// MARK: - Voice Pack Models
struct VoicePackCreationResponse: Content {
    let success: Bool
    let voicePackId: String
    let message: String
}

struct VoicePackStatus: Content {
    let voicePackId: String
    let name: String
    let status: String // "processing", "completed", "failed"
    let progress: Int // 0-100
    let readyToUse: Bool
    let createdAt: String
    let language: String
    let description: String?
}

struct SingerVoiceTrainingResponse: Content {
    let success: Bool
    let voicePackId: String
    let singerName: String
    let singerId: String
    let message: String
}

struct SingerStyle: Content {
    let pitch_shift: Double      // 음역대 조정 (0.5-3.0)
    let tempo_adjust: Double     // 템포 조정 (0.5-2.0)
    let vocal_range: String      // 음역대 타입 (soprano, mezzo-soprano, tenor, baritone, bass)
    let breathiness: Double      // 숨소리 정도 (0.0-1.0)
    let vibrato: Double          // 비브라토 강도 (0.0-1.0)
    let resonance: Double        // 공명 강도 (0.0-1.0)
}

// MARK: - Health Check Response
struct HealthCheckResponse: Content {
    let status: String
    let openvoiceInitialized: Bool
    let device: String
    let cudaAvailable: Bool
}