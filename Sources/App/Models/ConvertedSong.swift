import Fluent
import Vapor

final class ConvertedSong: Model, Content, @unchecked Sendable {
    static let schema = "converted_songs"

    @ID(key: .id)
    var id: UUID?

    @Parent(key: "user_id")
    var user: User

    @OptionalField(key: "source_track_id")
    var sourceTrackID: String?

    @Field(key: "source_key")
    var sourceKey: String

    @OptionalField(key: "source_playback_url")
    var sourcePlaybackURL: String?

    @Field(key: "title")
    var title: String

    @OptionalField(key: "artist_name")
    var artistName: String?

    @OptionalField(key: "artwork_url")
    var artworkURL: String?

    @Field(key: "voice_id")
    var voiceID: String

    @Field(key: "voice_name")
    var voiceName: String

    @OptionalField(key: "voice_type")
    var voiceType: String?

    @Field(key: "status")
    var status: String

    @OptionalField(key: "beam_svc_job_id")
    var beamSVCJobID: String?

    @OptionalField(key: "result_file_url")
    var resultFileURL: String?

    @OptionalField(key: "error_message")
    var errorMessage: String?

    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?

    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?

    init() {}

    init(
        id: UUID? = nil,
        userID: UUID,
        sourceTrackID: String?,
        sourceKey: String,
        sourcePlaybackURL: String?,
        title: String,
        artistName: String?,
        artworkURL: String?,
        voiceID: String,
        voiceName: String,
        voiceType: String?,
        status: String,
        beamSVCJobID: String? = nil,
        resultFileURL: String? = nil,
        errorMessage: String? = nil
    ) {
        self.id = id
        self.$user.id = userID
        self.sourceTrackID = sourceTrackID
        self.sourceKey = sourceKey
        self.sourcePlaybackURL = sourcePlaybackURL
        self.title = title
        self.artistName = artistName
        self.artworkURL = artworkURL
        self.voiceID = voiceID
        self.voiceName = voiceName
        self.voiceType = voiceType
        self.status = status
        self.beamSVCJobID = beamSVCJobID
        self.resultFileURL = resultFileURL
        self.errorMessage = errorMessage
    }
}
