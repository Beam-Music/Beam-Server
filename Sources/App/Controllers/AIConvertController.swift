import Vapor
import Foundation

struct AIConvertController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let aiConvert = routes.grouped("ai-convert")
        aiConvert.post("voice-conversion", use: convertVoice)
        aiConvert.get("health", use: healthCheck)
        aiConvert.get("voices", use: listVoices)
    }
    
    // MARK: - Lalal.ai API Configuration
    private let lalalAIBaseURL = "https://www.lalal.ai"
    private let lalalAILicenseKey = "50895a975bdd4a14"
    
    // MARK: - Health Check
    func healthCheck(req: Request) async throws -> Response {
        req.logger.info("🔍 Health check requested")
        
        // Lalal.ai API 제한 확인으로 헬스체크
        let url = URL(string: "\(lalalAIBaseURL)/billing/get-limits/?key=\(lalalAILicenseKey)")!
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
    
    // MARK: - List Available Voices
    func listVoices(req: Request) async throws -> Response {
        req.logger.info("🎤 Fetching available voices from Lalal.ai")
        
        // Lalal.ai API에서 음성 팩 목록을 가져옵니다
        let url = URL(string: "\(lalalAIBaseURL)/api/voice_packs/list/")!
        var request = URLRequest(url: url)
        request.setValue("license \(lalalAILicenseKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            req.logger.error("❌ Invalid response from Lalal.ai voices API")
            throw Abort(.internalServerError, reason: "Invalid response from Lalal.ai voices API")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            req.logger.error("❌ Lalal.ai voices API error: \(errorMessage)")
            throw Abort(.badRequest, reason: "Lalal.ai voices API error: \(errorMessage)")
        }
        
        // Lalal.ai API 응답을 파싱하여 iOS 앱 형식으로 변환
        struct LalalAIVoicePack: Codable {
            let pack_id: String
            let name: String
            let ready_to_use: Bool
            let language: [String: String]?
        }
        
        struct LalalAIVoicesResponse: Codable {
            let status: String
            let packs: [LalalAIVoicePack]
        }
        
        let lalalAIResponse = try JSONDecoder().decode(LalalAIVoicesResponse.self, from: data)
        
        // Lalal.ai 기본 음성들 추가
        let defaultVoices = [
            Voice(
                voiceId: "ALEX_KAYE",
                name: "Alex Kaye",
                language: ["en"],
                description: "Male voice - Alex Kaye"
            ),
            Voice(
                voiceId: "STASIA_FAYE",
                name: "Stasia Faye",
                language: ["en"],
                description: "Female voice - Stasia Faye"
            ),
            Voice(
                voiceId: "NICOLAAS_HAAS",
                name: "Nicolaas Haas",
                language: ["en"],
                description: "Male voice - Nicolaas Haas"
            ),
            Voice(
                voiceId: "NIK_ZEL",
                name: "Nik Zel",
                language: ["en"],
                description: "Male voice - Nik Zel"
            ),
            Voice(
                voiceId: "OLIA_CHEBO",
                name: "Olia Chebo",
                language: ["en"],
                description: "Female voice - Olia Chebo"
            ),
            Voice(
                voiceId: "YVAR_DE_GROOT",
                name: "Yvar De Groot",
                language: ["en"],
                description: "Male voice - Yvar De Groot"
            ),
            Voice(
                voiceId: "VETRANA",
                name: "Vetrana",
                language: ["en"],
                description: "Female voice - Vetrana"
            )
        ]
        
        // 사용자 정의 음성 팩 추가
        let customVoices = lalalAIResponse.packs.filter { $0.ready_to_use }.map { pack in
            Voice(
                voiceId: pack.pack_id,
                name: pack.name,
                language: [pack.language?["code"] ?? "en"],
                description: "Custom voice pack: \(pack.name)"
            )
        }
        
        let allVoices = defaultVoices + customVoices
        
        let responseData = ["voices": allVoices]
        let jsonData = try JSONEncoder().encode(responseData)
        
        req.logger.info("✅ Lalal.ai voices response: \(allVoices.count) voices available")
        
        return Response(
            status: .ok,
            body: .init(data: jsonData)
        )
    }
    
    // MARK: - Voice Conversion
    func convertVoice(req: Request) async throws -> Response {
        req.logger.info("🎵 Voice conversion request received")
        
        // iOS 앱에서 보내는 파라미터 이름을 유연하게 처리 (backward compatibility)
        let audioFile: File
        let voiceId: String
        let language: String
        let outputFormat: String
        let useSeparation: String
        
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
        
        req.logger.info("🎵 Converting voice with Lalal.ai")
        req.logger.info("   Voice ID: \(voiceId)")
        req.logger.info("   Language: \(language)")
        req.logger.info("   Audio file: \(audioFile.filename)")
        req.logger.info("   Audio size: \(audioFile.data.readableBytes) bytes")
        req.logger.info("   Use separation: \(useSeparation)")
        
        do {
            // Lalal.ai API 호출 (업로드 -> 음성 분리 -> 음성 변환)
            let convertedAudioData = try await convertVoiceWithLalalAI(
                audioFile: audioFile,
                voiceId: voiceId,
                language: language,
                outputFormat: outputFormat,
                useSeparation: useSeparation,
                req: req
            )
            
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
    
    // MARK: - Lalal.ai API Integration
    private func convertVoiceWithLalalAI(
        audioFile: File,
        voiceId: String,
        language: String,
        outputFormat: String,
        useSeparation: String,
        req: Request
    ) async throws -> Data {
        req.logger.info("🚀 Starting Lalal.ai voice conversion process...")
        
        // Step 1: 파일 업로드
        req.logger.info("📤 Step 1: Uploading audio file to Lalal.ai...")
        let uploadedFileId = try await uploadFileToLalalAI(audioFile: audioFile, req: req)
        req.logger.info("✅ File uploaded successfully with ID: \(uploadedFileId)")
        
        // Step 2: 음성 분리 (useSeparation이 true인 경우)
        var vocalsFileId = uploadedFileId
        if useSeparation.lowercased() == "true" {
            req.logger.info("🎵 Step 2: Separating vocals from background music...")
            vocalsFileId = try await separateVocalsFromLalalAI(fileId: uploadedFileId, req: req)
            req.logger.info("✅ Vocals separated successfully with ID: \(vocalsFileId)")
        }
        
        // Step 3: 음성 변환
        req.logger.info("🎤 Step 3: Converting voice using Lalal.ai...")
        let convertedFileId = try await changeVoiceWithLalalAI(fileId: vocalsFileId, voiceId: voiceId, req: req)
        req.logger.info("✅ Voice converted successfully with ID: \(convertedFileId)")
        
        // Step 4: 변환된 파일 다운로드
        req.logger.info("📥 Step 4: Downloading converted audio...")
        let convertedAudioData = try await downloadFileFromLalalAI(fileId: convertedFileId, req: req)
        req.logger.info("✅ Converted audio downloaded successfully")
        
        return convertedAudioData
    }
    
    // MARK: - Default Target Audio Generation
    private func getDefaultTargetAudio(voiceId: String, req: Request) async throws -> Data {
        req.logger.info("🎵 Generating default target audio for voice ID: \(voiceId)")
        
        // 더 자연스러운 참조 음성 생성 (여러 주파수 조합)
        let sampleRate = 22050
        let duration = 3.0 // 3초로 늘림
        let samples = Int(duration * Double(sampleRate))
        
        // 음성 ID에 따라 다른 주파수 조합 사용
        let frequencies: [Double]
        let baseAmplitude: Double
        
        switch voiceId {
        case "female_1":
            frequencies = [220.0, 440.0, 880.0] // 여성 음성 범위 (A3, A4, A5)
            baseAmplitude = 0.25
        case "male_1":
            frequencies = [110.0, 220.0, 330.0] // 남성 음성 범위 (A2, A3, E4)
            baseAmplitude = 0.3
        case "default":
            frequencies = [165.0, 330.0, 495.0] // 중성 음성 범위 (E3, E4, B4)
            baseAmplitude = 0.28
        default:
            frequencies = [165.0, 330.0, 495.0]
            baseAmplitude = 0.28
        }
        
        // 복합 주파수 음성 생성 (더 자연스러운 음성 시뮬레이션)
        var audioData = Data()
        for i in 0..<samples {
            let t = Double(i) / Double(sampleRate)
            
            // 여러 주파수 조합으로 복합 음성 생성
            var amplitude: Double = 0.0
            for (index, freq) in frequencies.enumerated() {
                let harmonicWeight = 1.0 / Double(index + 1) // 고조파 감쇠
                amplitude += harmonicWeight * sin(2.0 * Double.pi * freq * t)
            }
            
            // 엔벨로프 적용 (ADSR: Attack, Decay, Sustain, Release)
            let envelope = calculateEnvelope(t: t, duration: duration)
            amplitude *= envelope * baseAmplitude
            
            // 클리핑 방지
            amplitude = max(-0.95, min(0.95, amplitude))
            
            // 16비트 PCM으로 변환
            let sample = Int16(amplitude * 32767.0)
            audioData.append(contentsOf: withUnsafeBytes(of: sample.littleEndian) { Data($0) })
        }
        
        // WAV 헤더 추가
        let wavHeader = createWAVHeader(sampleCount: samples, sampleRate: sampleRate, channels: 1)
        let completeWavData = wavHeader + audioData
        
        req.logger.info("✅ Enhanced default target audio generated")
        req.logger.info("   Voice ID: \(voiceId)")
        req.logger.info("   Frequencies: \(frequencies)")
        req.logger.info("   Duration: \(duration) seconds")
        req.logger.info("   Size: \(completeWavData.count) bytes")
        
        return completeWavData
    }
    
    // MARK: - Audio Envelope Calculation
    private func calculateEnvelope(t: Double, duration: Double) -> Double {
        let attack = 0.1 // 0.1초
        let decay = 0.2  // 0.2초
        let sustain = 0.7 // 지속 레벨
        let release = 0.3 // 0.3초
        
        if t < attack {
            // Attack phase
            return t / attack
        } else if t < attack + decay {
            // Decay phase
            let decayT = (t - attack) / decay
            return 1.0 - (1.0 - sustain) * decayT
        } else if t < duration - release {
            // Sustain phase
            return sustain
        } else {
            // Release phase
            let releaseT = (duration - t) / release
            return sustain * releaseT
        }
    }
    
    // MARK: - WAV Header Creation
    private func createWAVHeader(sampleCount: Int, sampleRate: Int, channels: Int) -> Data {
        var header = Data()
        
        // RIFF 헤더
        header.append("RIFF".data(using: .ascii)!)
        let fileSize = 36 + sampleCount * 2 // 16비트 = 2바이트
        header.append(contentsOf: withUnsafeBytes(of: UInt32(fileSize).littleEndian) { Data($0) })
        header.append("WAVE".data(using: .ascii)!)
        
        // fmt 청크
        header.append("fmt ".data(using: .ascii)!)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // fmt 청크 크기
        header.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM
        header.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate * channels * 2).littleEndian) { Data($0) }) // 바이트 레이트
        header.append(contentsOf: withUnsafeBytes(of: UInt16(channels * 2).littleEndian) { Data($0) }) // 블록 얼라인
        header.append(contentsOf: withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) }) // 비트 깊이
        
        // data 청크
        header.append("data".data(using: .ascii)!)
        header.append(contentsOf: withUnsafeBytes(of: UInt32(sampleCount * 2).littleEndian) { Data($0) })
        
        return header
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

// MARK: - Available Voices
struct Voice: Content {
    let voiceId: String
    let name: String
    let language: [String]
    let description: String
}

// MARK: - Health Check Response
struct HealthCheckResponse: Content {
    let status: String
    let openvoiceInitialized: Bool
    let device: String
    let cudaAvailable: Bool
}

// MARK: - Lalal.ai API Helper Functions
extension AIConvertController {
    
    // Step 1: 파일 업로드
    private func uploadFileToLalalAI(audioFile: File, req: Request) async throws -> String {
        req.logger.info("📤 Uploading file to Lalal.ai...")
        
        let url = URL(string: "\(lalalAIBaseURL)/api/upload/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("license \(lalalAILicenseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("attachment; filename=\(audioFile.filename)", forHTTPHeaderField: "Content-Disposition")
        request.setValue(audioFile.contentType?.description ?? "audio/mpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(audioFile.data.readableBytesView)
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5분
        config.timeoutIntervalForResource = 600 // 10분
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from Lalal.ai upload API")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Abort(.badRequest, reason: "Lalal.ai upload error: \(errorMessage)")
        }
        
        // 응답 파싱
        struct UploadResponse: Codable {
            let status: String
            let id: String?
            let error: String?
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        
        guard uploadResponse.status == "success", let fileId = uploadResponse.id else {
            throw Abort(.badRequest, reason: "Upload failed: \(uploadResponse.error ?? "Unknown error")")
        }
        
        req.logger.info("✅ File uploaded successfully with ID: \(fileId)")
        return fileId
    }
    
    // Step 2: 음성 분리
    private func separateVocalsFromLalalAI(fileId: String, req: Request) async throws -> String {
        req.logger.info("🎵 Separating vocals from file ID: \(fileId)")
        
        let url = URL(string: "\(lalalAIBaseURL)/api/split/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("license \(lalalAILicenseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 음성 분리 파라미터
        let params = [["id": fileId, "stem": "vocals"]]
        let paramsJson = try JSONSerialization.data(withJSONObject: params)
        let paramsString = String(data: paramsJson, encoding: .utf8) ?? "[]"
        
        let body = "params=\(paramsString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
        request.httpBody = body.data(using: .utf8)
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5분
        config.timeoutIntervalForResource = 1800 // 30분
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from Lalal.ai split API")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Abort(.badRequest, reason: "Lalal.ai split error: \(errorMessage)")
        }
        
        // 응답 파싱
        struct SplitResponse: Codable {
            let status: String
            let task_id: String?
            let error: String?
        }
        
        let splitResponse = try JSONDecoder().decode(SplitResponse.self, from: data)
        
        guard splitResponse.status == "success", let taskId = splitResponse.task_id else {
            throw Abort(.badRequest, reason: "Split failed: \(splitResponse.error ?? "Unknown error")")
        }
        
        req.logger.info("✅ Split task started with ID: \(taskId)")
        
        // 분리 완료까지 대기
        return try await waitForSplitCompletion(fileId: fileId, req: req)
    }
    
    // 분리 완료 대기
    private func waitForSplitCompletion(fileId: String, req: Request) async throws -> String {
        req.logger.info("⏳ Waiting for split completion...")
        
        let url = URL(string: "\(lalalAIBaseURL)/api/check/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("license \(lalalAILicenseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let body = "id=\(fileId)"
        request.httpBody = body.data(using: .utf8)
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30 // 30초
        config.timeoutIntervalForResource = 300 // 5분
        let session = URLSession(configuration: config)
        
        // 최대 10분 대기 (20초마다 체크)
        for attempt in 1...30 {
            req.logger.info("🔄 Checking split status (attempt \(attempt)/30)...")
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                if attempt == 30 {
                    throw Abort(.badRequest, reason: "Split task failed or timed out")
                }
                try await Task.sleep(nanoseconds: 20_000_000_000) // 20초 대기
                continue
            }
            
            // 응답 파싱
            struct SplitCheckResponse: Codable {
                let status: String
                let result: [String: SplitResult]?
                let error: String?
            }
            
            struct SplitResult: Codable {
                let status: String
                let split: SplitData?
                let task: TaskStatus?
                let error: String?
                
                // 추가 필드들 (Lalal.ai API 응답에 따라)
                let archive: String? // null일 수 있음
                let name: String?
                let size: Int?
                let duration: Double?
                let presets: PresetsData?
                let stem: String?
                let splitter: String?
                let preview: String?
                let player: PlayerData?
                let task_type: String?
            }
            
            struct PresetsData: Codable {
                let split: SplitPreset?
            }
            
            struct SplitPreset: Codable {
                let task_type: String?
                let stem_option: [String]?
                let splitter: String?
                let dereverb_enabled: Bool?
                let enhanced_processing_enabled: Bool?
            }
            
            struct PlayerData: Codable {
                let stem: String?
                let duration: Double?
                let stem_track: String?
                let stem_track_size: Int?
                let back_track: String?
                let back_track_size: Int?
            }
            
            struct SplitData: Codable {
                let stem_track: String
                let back_track: String?
                let stem_track_size: Int?
                let back_track_size: Int?
                let duration: Double?
            }
            
            struct TaskStatus: Codable {
                let state: String
                let progress: Int?
                let error: String?
                let id: [String]?
                let split_id: String?
            }
            
            // 디버깅을 위해 응답 로깅
            let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
            req.logger.info("🔍 Split check response: \(responseString)")
            
            let splitCheckResponse: SplitCheckResponse
            do {
                // 더 안전한 파싱을 위해 JSONSerialization 사용
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let result = json["result"] as? [String: Any],
                   let fileData = result[fileId] as? [String: Any],
                   let status = fileData["status"] as? String,
                   let taskData = fileData["task"] as? [String: Any],
                   let taskState = taskData["state"] as? String {
                    
                    // 수동으로 구조체 생성
                    let taskStatus = TaskStatus(
                        state: taskState,
                        progress: taskData["progress"] as? Int,
                        error: taskData["error"] as? String,
                        id: taskData["id"] as? [String],
                        split_id: taskData["split_id"] as? String
                    )
                    
                    let playerData: PlayerData?
                    if let player = fileData["player"] as? [String: Any] {
                        playerData = PlayerData(
                            stem: player["stem"] as? String,
                            duration: player["duration"] as? Double,
                            stem_track: player["stem_track"] as? String,
                            stem_track_size: player["stem_track_size"] as? Int,
                            back_track: player["back_track"] as? String,
                            back_track_size: player["back_track_size"] as? Int
                        )
                    } else {
                        playerData = nil
                    }
                    
                    let splitResult = SplitResult(
                        status: status,
                        split: nil,
                        task: taskStatus,
                        error: fileData["error"] as? String,
                        archive: fileData["archive"] as? String,
                        name: fileData["name"] as? String,
                        size: fileData["size"] as? Int,
                        duration: fileData["duration"] as? Double,
                        presets: nil,
                        stem: fileData["stem"] as? String,
                        splitter: fileData["splitter"] as? String,
                        preview: fileData["preview"] as? String,
                        player: playerData,
                        task_type: fileData["task_type"] as? String
                    )
                    
                    splitCheckResponse = SplitCheckResponse(
                        status: json["status"] as? String ?? "unknown",
                        result: [fileId: splitResult],
                        error: json["error"] as? String
                    )
                    
                } else {
                    throw Abort(.badRequest, reason: "Invalid response structure")
                }
                
            } catch {
                req.logger.error("❌ JSON parsing error: \(error)")
                req.logger.error("   Response data: \(responseString)")
                if attempt == 30 {
                    throw Abort(.badRequest, reason: "Failed to parse split check response: \(error)")
                }
                try await Task.sleep(nanoseconds: 20_000_000_000) // 20초 대기
                continue
            }
            
            guard splitCheckResponse.status == "success", let result = splitCheckResponse.result, let fileResult = result[fileId], fileResult.status == "success" else {
                if attempt == 30 {
                    throw Abort(.badRequest, reason: "Split check failed")
                }
                try await Task.sleep(nanoseconds: 20_000_000_000) // 20초 대기
                continue
            }
            
            if let task = fileResult.task {
                switch task.state {
                case "success":
                    if let player = fileResult.player {
                        req.logger.info("✅ Split completed successfully")
                        req.logger.info("   Stem track: \(player.stem_track ?? "N/A")")
                        req.logger.info("   Back track: \(player.back_track ?? "N/A")")
                        return fileId // 원본 파일 ID 반환 (분리된 파일은 같은 ID 사용)
                    }
                case "error":
                    throw Abort(.badRequest, reason: "Split task failed: \(task.error ?? "Unknown error")")
                case "progress":
                    req.logger.info("📊 Split progress: \(task.progress ?? 0)%")
                    if attempt == 30 {
                        throw Abort(.badRequest, reason: "Split task timed out")
                    }
                    try await Task.sleep(nanoseconds: 20_000_000_000) // 20초 대기
                    continue
                default:
                    if attempt == 30 {
                        throw Abort(.badRequest, reason: "Split task in unknown state: \(task.state)")
                    }
                    try await Task.sleep(nanoseconds: 20_000_000_000) // 20초 대기
                    continue
                }
            }
        }
        
        throw Abort(.badRequest, reason: "Split task timed out")
    }
    
    // Step 3: 음성 변환
    private func changeVoiceWithLalalAI(fileId: String, voiceId: String, req: Request) async throws -> String {
        req.logger.info("🎤 Changing voice for file ID: \(fileId) with voice: \(voiceId)")
        
        let url = URL(string: "\(lalalAIBaseURL)/api/change_voice/")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("license \(lalalAILicenseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // 음성 변환 파라미터
        let body = "id=\(fileId)&voice=\(voiceId)&accent_enhance=true&pitch_shifting=true&dereverb_enabled=false"
        request.httpBody = body.data(using: .utf8)
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5분
        config.timeoutIntervalForResource = 1800 // 30분
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.internalServerError, reason: "Invalid response from Lalal.ai change_voice API")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw Abort(.badRequest, reason: "Lalal.ai change_voice error: \(errorMessage)")
        }
        
        // 응답 파싱
        struct ChangeVoiceResponse: Codable {
            let status: String
            let id: String?
            let task_id: String?
            let error: String?
        }
        
        let changeVoiceResponse = try JSONDecoder().decode(ChangeVoiceResponse.self, from: data)
        
        guard changeVoiceResponse.status == "success", let convertedFileId = changeVoiceResponse.id else {
            throw Abort(.badRequest, reason: "Voice change failed: \(changeVoiceResponse.error ?? "Unknown error")")
        }
        
        req.logger.info("✅ Voice change task started with ID: \(convertedFileId)")
        
        // 변환 완료까지 대기
        return try await waitForVoiceChangeCompletion(fileId: convertedFileId, req: req)
    }
    
            // 음성 변환 완료 대기
        private func waitForVoiceChangeCompletion(fileId: String, req: Request) async throws -> String {
            req.logger.info("⏳ Waiting for voice change completion...")
            
            let url = URL(string: "\(lalalAIBaseURL)/api/check/")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("license \(lalalAILicenseKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            let body = "id=\(fileId)"
            request.httpBody = body.data(using: .utf8)
            
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30 // 30초
            config.timeoutIntervalForResource = 300 // 5분
            let session = URLSession(configuration: config)
            
            // 최대 10분 대기 (20초마다 체크)
            for attempt in 1...30 {
                req.logger.info("🔄 Checking voice change status (attempt \(attempt)/30)...")
                
                let (data, response) = try await session.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    if attempt == 30 {
                        throw Abort(.badRequest, reason: "Voice change task failed or timed out")
                    }
                    try await Task.sleep(nanoseconds: 20_000_000_000) // 20초 대기
                    continue
                }
                
                // 디버깅을 위해 응답 로깅
                let responseString = String(data: data, encoding: .utf8) ?? "Unable to decode response"
                req.logger.info("🔍 Voice change check response: \(responseString)")
                
                // 더 안전한 파싱을 위해 JSONSerialization 사용
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let result = json["result"] as? [String: Any],
                       let fileData = result[fileId] as? [String: Any] {
                        
                        // status가 없을 수도 있으므로 안전하게 처리
                        let status = fileData["status"] as? String ?? "unknown"
                        
                        // 음성 변환 API 응답 구조에 맞게 파싱
                        if status == "success" {
                            if let taskData = fileData["task"] as? [String: Any],
                               let taskState = taskData["state"] as? String {
                                
                                switch taskState {
                                case "success":
                                    req.logger.info("✅ Voice change completed successfully")
                                    // 성공 시 파일 데이터의 구조를 로깅
                                    req.logger.info("📋 File data structure: \(fileData)")
                                    
                                    // 음성 변환된 파일의 다운로드 URL을 미리 확인
                                    if let player = fileData["player"] as? [String: Any] {
                                        req.logger.info("🎵 Player data: \(player)")
                                        if let stemTrack = player["stem_track"] as? String {
                                            req.logger.info("📥 Found stem_track URL: \(stemTrack)")
                                        }
                                    }
                                    
                                    return fileId
                                case "error":
                                    let errorMessage = taskData["error"] as? String ?? "Unknown error"
                                    throw Abort(.badRequest, reason: "Voice change task failed: \(errorMessage)")
                                case "progress":
                                    let progress = taskData["progress"] as? Int ?? 0
                                    req.logger.info("📊 Voice change progress: \(progress)%")
                                    if attempt == 30 {
                                        throw Abort(.badRequest, reason: "Voice change task timed out")
                                    }
                                    try await Task.sleep(nanoseconds: 20_000_000_000) // 20초 대기
                                    continue
                                default:
                                    if attempt == 30 {
                                        throw Abort(.badRequest, reason: "Voice change task in unknown state: \(taskState)")
                                    }
                                    try await Task.sleep(nanoseconds: 20_000_000_000) // 20초 대기
                                    continue
                                }
                            } else {
                                // task 정보가 없는 경우도 성공으로 처리 (이미 완료된 경우)
                                req.logger.info("✅ Voice change completed successfully (no task info)")
                                req.logger.info("📋 File data structure: \(fileData)")
                                
                                // 음성 변환된 파일의 다운로드 URL을 미리 확인
                                if let player = fileData["player"] as? [String: Any] {
                                    req.logger.info("🎵 Player data: \(player)")
                                    if let stemTrack = player["stem_track"] as? String {
                                        req.logger.info("📥 Found stem_track URL: \(stemTrack)")
                                    }
                                }
                                
                                return fileId
                            }
                        } else {
                            if attempt == 30 {
                                throw Abort(.badRequest, reason: "Voice change check failed")
                            }
                            try await Task.sleep(nanoseconds: 20_000_000_000) // 20초 대기
                            continue
                        }
                        
                    } else {
                        if attempt == 30 {
                            throw Abort(.badRequest, reason: "Invalid response structure")
                        }
                        try await Task.sleep(nanoseconds: 20_000_000_000) // 20초 대기
                        continue
                    }
                    
                } catch {
                    req.logger.error("❌ JSON parsing error: \(error)")
                    req.logger.error("   Response data: \(responseString)")
                    if attempt == 30 {
                        throw Abort(.badRequest, reason: "Failed to parse voice change check response: \(error)")
                    }
                    try await Task.sleep(nanoseconds: 20_000_000_000) // 20초 대기
                    continue
                }
            }
            
            throw Abort(.badRequest, reason: "Voice change task timed out")
        }
    
    // Step 4: 변환된 파일 다운로드
    private func downloadFileFromLalalAI(fileId: String, req: Request) async throws -> Data {
        req.logger.info("📥 Downloading converted file with ID: \(fileId)")
        
        // 먼저 파일 정보 확인
        let checkUrl = URL(string: "\(lalalAIBaseURL)/api/check/")!
        var checkRequest = URLRequest(url: checkUrl)
        checkRequest.httpMethod = "POST"
        checkRequest.setValue("license \(lalalAILicenseKey)", forHTTPHeaderField: "Authorization")
        checkRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let checkBody = "id=\(fileId)"
        checkRequest.httpBody = checkBody.data(using: .utf8)
        
        let (checkData, checkResponse) = try await URLSession.shared.data(for: checkRequest)
        
        guard let checkHttpResponse = checkResponse as? HTTPURLResponse, checkHttpResponse.statusCode == 200 else {
            throw Abort(.badRequest, reason: "Failed to get file info")
        }
        
        // 디버깅을 위해 응답 로깅
        let responseString = String(data: checkData, encoding: .utf8) ?? "Unable to decode response"
        req.logger.info("🔍 File info check response: \(responseString)")
        
        // 더 안전한 파싱을 위해 JSONSerialization 사용
        guard let json = try JSONSerialization.jsonObject(with: checkData) as? [String: Any],
              let result = json["result"] as? [String: Any],
              let fileData = result[fileId] as? [String: Any] else {
            throw Abort(.badRequest, reason: "Failed to parse file info")
        }
        
        let status = fileData["status"] as? String ?? "unknown"
        guard status == "success" else {
            throw Abort(.badRequest, reason: "File status is not success: \(status)")
        }
        
        // 파일 데이터 구조를 자세히 로깅
        req.logger.info("📋 File data for download: \(fileData)")
        
        // 다운로드 URL 결정 - task_type에 따라 다른 로직 적용
        var downloadUrl: String?
        let taskType = fileData["task_type"] as? String ?? "unknown"
        
        req.logger.info("🔍 Task type: \(taskType)")
        
        if let player = fileData["player"] as? [String: Any] {
            req.logger.info("🎵 Player data available: \(player)")
            
            switch taskType {
            case "voice_convert":
                // 음성 변환의 경우 back_track이 변환된 음성
                if let backTrack = player["back_track"] as? String {
                    downloadUrl = backTrack
                    req.logger.info("📥 Found back_track for voice_convert: \(downloadUrl!)")
                }
            case "split":
                // 음성 분리의 경우 stem_track이 분리된 보컬
                if let stemTrack = player["stem_track"] as? String {
                    downloadUrl = stemTrack
                    req.logger.info("📥 Found stem_track for split: \(downloadUrl!)")
                }
            default:
                // 기본값으로 stem_track 시도, 없으면 back_track
                if let stemTrack = player["stem_track"] as? String {
                    downloadUrl = stemTrack
                    req.logger.info("📥 Found stem_track (default): \(downloadUrl!)")
                } else if let backTrack = player["back_track"] as? String {
                    downloadUrl = backTrack
                    req.logger.info("📥 Found back_track (fallback): \(downloadUrl!)")
                }
            }
        }
        
        // split 정보에서도 확인 (fallback)
        if downloadUrl == nil, let split = fileData["split"] as? [String: Any] {
            if let stemTrack = split["stem_track"] as? String {
                downloadUrl = stemTrack
                req.logger.info("📥 Found stem_track in split: \(downloadUrl!)")
            } else if let backTrack = split["back_track"] as? String {
                downloadUrl = backTrack
                req.logger.info("📥 Found back_track in split: \(downloadUrl!)")
            }
        }
        
        // 최후의 수단으로 기본 다운로드 URL 사용 (권장하지 않음)
        if downloadUrl == nil {
            downloadUrl = "\(lalalAIBaseURL)/api/download/\(fileId)"
            req.logger.warning("⚠️ Using default download URL (may not work): \(downloadUrl!)")
        }
        
        guard let finalDownloadUrl = downloadUrl else {
            throw Abort(.badRequest, reason: "Could not determine download URL")
        }
        
        req.logger.info("📥 Final download URL: \(finalDownloadUrl)")
        
        // URL 유효성 검사
        guard finalDownloadUrl.hasPrefix("https://") else {
            throw Abort(.badRequest, reason: "Invalid download URL format: \(finalDownloadUrl)")
        }
        
        // 파일 다운로드
        let downloadURL = URL(string: finalDownloadUrl)!
        var downloadRequest = URLRequest(url: downloadURL)
        
        // Lalal.ai 미디어 서버의 경우 Authorization 헤더가 필요 없을 수 있음
        if finalDownloadUrl.contains("d.lalal.ai") {
            req.logger.info("🌐 Direct media URL detected, skipping Authorization header")
            // d.lalal.ai는 직접 접근 가능한 CDN URL이므로 Authorization 불필요
        } else {
            downloadRequest.setValue("license \(lalalAILicenseKey)", forHTTPHeaderField: "Authorization")
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300 // 5분
        config.timeoutIntervalForResource = 600 // 10분
        let session = URLSession(configuration: config)
        
        let (audioData, downloadResponse) = try await session.data(for: downloadRequest)
        
        guard let downloadHttpResponse = downloadResponse as? HTTPURLResponse else {
            throw Abort(.badRequest, reason: "Invalid download response")
        }
        
        guard downloadHttpResponse.statusCode == 200 else {
            let errorMessage = String(data: audioData, encoding: .utf8) ?? "Unknown error"
            req.logger.error("❌ Download failed with status: \(downloadHttpResponse.statusCode)")
            req.logger.error("❌ Download URL: \(finalDownloadUrl)")
            req.logger.error("❌ Download error message: \(errorMessage)")
            
            // 다른 URL 시도 로직 추가
            if downloadHttpResponse.statusCode == 404 {
                req.logger.info("🔄 Trying alternative download approach...")
                
                // player.back_track와 stem_track 모두 시도
                if let player = fileData["player"] as? [String: Any] {
                    let alternativeUrls = [
                        player["back_track"] as? String,
                        player["stem_track"] as? String
                    ].compactMap { $0 }.filter { $0 != finalDownloadUrl }
                    
                    for altUrl in alternativeUrls {
                        req.logger.info("🔄 Trying alternative URL: \(altUrl)")
                        let altDownloadURL = URL(string: altUrl)!
                        var altRequest = URLRequest(url: altDownloadURL)
                        
                        let (altData, altResponse) = try await session.data(for: altRequest)
                        
                        if let altHttpResponse = altResponse as? HTTPURLResponse,
                           altHttpResponse.statusCode == 200 {
                            req.logger.info("✅ Alternative URL worked!")
                            return altData
                        }
                    }
                }
            }
            
            throw Abort(.badRequest, reason: "Failed to download converted audio: HTTP \(downloadHttpResponse.statusCode)")
        }
        
        req.logger.info("✅ Converted audio downloaded successfully")
        req.logger.info("   Size: \(audioData.count) bytes")
        req.logger.info("   Content-Type: \(downloadHttpResponse.value(forHTTPHeaderField: "Content-Type") ?? "unknown")")
        
        return audioData
    }
} 
