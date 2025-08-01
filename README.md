# Beam-Server

Beam-Server는 Vapor 4와 Swift로 구축된 Beam Music 애플리케이션의 백엔드 서비스입니다. 음악 스트리밍, 플레이리스트 관리, AI 기반 음악 추천 기능을 위한 RESTful API를 제공합니다.

## 🏗 아키텍처

### 프로젝트 구조

```
Sources/
├── App/
│   ├── Controllers/     # 요청 처리 및 비즈니스 로직
│   ├── Models/          # 데이터베이스 모델 및 DTO
│   ├── Migrations/      # 데이터베이스 마이그레이션
│   ├── Extensions/      # Swift 확장
│   ├── Middleware/      # 커스텀 미들웨어
│   ├── Services/        # 비즈니스 로직 서비스
│   ├── Utils/          # 유틸리티 함수 및 헬퍼
│   ├── configure.swift  # 애플리케이션 설정
│   └── routes.swift     # 라우트 설정
└── Run/                 # 애플리케이션 진입점
```

### 주요 구성 요소

- **인증**: JWT 기반 인증 시스템
- **데이터베이스**: PostgreSQL과 Fluent ORM
- **이메일 서비스**: SendGrid 통합 이메일 인증
- **AI 통합**: 커스텀 AI 음악 추천 시스템
- **음성 변환**: Lalal.ai Voice Conversion API 통합
- **음악 스트리밍**: 고품질 음원 스트리밍 서비스
- **사용자 관리**: 프로필, 설정, 청취 기록 관리

## 🚀 시작하기

### 사전 요구사항

- Swift 5.9+
- PostgreSQL 14+
- Docker (선택사항)

### 환경 변수

루트 디렉토리에 다음 변수들을 포함한 `.env` 파일을 생성하세요:

```env
DATABASE_URL=postgresql://username:password@host:port/database
SENDGRID_API_KEY=your_sendgrid_api_key
JWT_SECRET=your_jwt_secret
# Lalal.ai API 키 필요 (클라우드 서비스)
```

### 로컬 개발 환경 설정

1. 저장소 클론:

```bash
git clone https://github.com/Beam-Music/Beam-Server.git
cd Beam-Server
```

2. 의존성 설치:

```bash
swift package resolve
```

3. 마이그레이션 실행:

```bash
swift run App migrate
```

4. 서버 실행:

```bash
swift run
```

서버는 `http://localhost:8080`에서 실행됩니다.

### Docker 배포

1. Docker 이미지 빌드:

```bash
docker build -t beam-server .
```

2. 컨테이너 실행:

```bash
docker run -p 8080:8080 --env-file .env beam-server
```

## 📚 API 문서

### 인증

- `POST /api/users/register`: 새 사용자 등록
- `POST /api/users/verify`: 이메일 주소 인증
- `POST /api/users/login`: 사용자 로그인

### 사용자 정보

- `GET /api/users/profile`: 사용자 프로필 조회
- `PUT /api/users/profile`: 프로필 정보 수정
- `GET /api/users/preferences`: 사용자 설정 조회
- `PUT /api/users/preferences`: 사용자 설정 수정
- `GET /api/users/listening-history`: 청취 기록 조회
- `GET /api/users/favorites`: 좋아요한 곡 목록 조회

### 음악 재생

- `GET /api/tracks/{id}`: 음원 스트리밍
- `GET /api/tracks/{id}/metadata`: 음원 메타데이터 조회
- `POST /api/tracks/{id}/play`: 재생 시작 기록
- `POST /api/tracks/{id}/complete`: 재생 완료 기록
- `POST /api/tracks/{id}/like`: 좋아요 표시
- `POST /api/tracks/{id}/unlike`: 좋아요 취소
- `GET /api/tracks/{id}/lyrics`: 가사 조회
- `GET /api/tracks/{id}/waveform`: 파형 데이터 조회

### 플레이리스트

- `GET /recommend-playlists`: AI 추천 플레이리스트 조회
- `GET /user-playlists`: 사용자 플레이리스트 조회
- `POST /user-playlists`: 새 플레이리스트 생성

### AI 음악

- `GET /api/ai-songs/playable`: AI 생성 음악 조회
- `POST /api/ai-songs/register`: 새로운 AI 생성 음악 등록

### 음성 변환 (Lalal.ai)

#### 음성 변환

- `POST /ai-convert/voice-conversion`: 기존 음성을 다른 음성으로 변환
  - `audioFile`: 변환할 오디오 파일
  - `voiceId`: 대상 음성 ID (예: "en_female_1", "ko_male_1")
  - `outputFormat`: 출력 형식 (기본값: wav)
  - `language`: 언어 코드 (예: "ko", "en", "ja")
  - `useSeparation`: 음성 분리 사용 여부 (기본값: "true")
    - `"true"`: Spleeter를 사용해 음성과 배경음악을 분리한 후 음성만 변환 (고품질)
    - `"false"`: 전체 오디오를 직접 변환 (기본 방식)

#### 음성 목록 조회

- `GET /ai-convert/voices`: 사용 가능한 음성 목록 조회
  - 기본 제공 보이스: 영어, 한국어, 일본어 남성/여성 보이스

#### 서버 상태 확인

- `GET /ai-convert/health`: Lalal.ai 서버 상태 확인

#### 음성 변환 사용 예시

1. **서버 상태 확인**:

```bash
# Lalal.ai 서버 상태 확인
curl http://localhost:8080/ai-convert/health
```

2. **음성 목록 조회**:

```bash
# 사용 가능한 보이스 목록 조회
curl http://localhost:8080/ai-convert/voices
```

3. **음성 변환**:

```bash
# 고품질 음성 변환 (음성 분리 사용)
curl -X POST http://localhost:8080/ai-convert/voice-conversion \
  -F "audioFile=@original_song.mp3" \
  -F "voiceId=ko_female_1" \
  -F "language=ko" \
  -F "outputFormat=wav" \
  -F "useSeparation=true" \
  --output converted_song.wav

# 기본 음성 변환 (전체 오디오 변환)
curl -X POST http://localhost:8080/ai-convert/voice-conversion \
  -F "audioFile=@original_song.mp3" \
  -F "voiceId=ko_female_1" \
  -F "language=ko" \
  -F "outputFormat=wav" \
  -F "useSeparation=false" \
  --output converted_song.wav
```

**참고**: Lalal.ai는 클라우드 API 서비스로 별도 서버 설정이 필요하지 않습니다.

## 🔒 보안

- 모든 민감 정보는 환경 변수에 저장
- API 엔드포인트용 JWT 인증
- 데이터베이스 연결을 위한 SSL/TLS 암호화
- 새 계정에 대한 이메일 인증
- Bcrypt를 사용한 비밀번호 해싱

## 🏛 아키텍처 결정사항

### 클린 아키텍처

프로젝트는 클린 아키텍처 원칙을 따릅니다:

- 컨트롤러는 HTTP 요청과 응답을 처리
- 서비스는 비즈니스 로직을 포함
- 모델은 데이터베이스 엔티티를 표현
- DTO는 데이터 전송을 처리

### 데이터베이스 설계

- 타입 안전한 데이터베이스 쿼리를 위한 Fluent ORM 사용
- 데이터베이스 스키마 버전 관리를 위한 마이그레이션
- 엔티티 간 관계 관리 (사용자, 플레이리스트, 음악)

### 오류 처리

- 다양한 시나리오에 대한 커스텀 오류 타입
- API 전반에 걸친 일관된 오류 응답
- 디버깅을 위한 상세 로깅

### 음악 스트리밍 아키텍처

- HLS(HTTP Live Streaming) 프로토콜 사용
- 적응형 비트레이트 스트리밍 지원
- CDN을 통한 글로벌 콘텐츠 전송
- 음원 캐싱 및 최적화
- 실시간 트랜스코딩 지원

### 사용자 데이터 관리

- 개인정보 보호를 위한 데이터 암호화
- 사용자 활동 로깅 및 분석
- 청취 기록 기반 개인화 추천
- 설정 및 선호도 동기화
- 소셜 기능 통합

## 🚥 CI/CD

- 자동화된 테스트를 위한 GitHub Actions
- Docker를 통한 프로덕션 배포
- 자동 데이터베이스 마이그레이션
- 환경 기반 설정

## 📈 모니터링

- 내장된 요청 로깅
- 오류 추적
- 성능 모니터링
- 데이터베이스 쿼리 로깅

## 🤝 기여하기

1. 저장소 포크
2. 기능 브랜치 생성
3. 변경사항 커밋
4. 브랜치에 푸시
5. Pull Request 생성

## 📝 라이선스

이 프로젝트는 MIT 라이선스를 따릅니다 - 자세한 내용은 LICENSE 파일을 참조하세요.
