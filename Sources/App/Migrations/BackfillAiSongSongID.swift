import Fluent
import Vapor

struct BackfillAiSongSongID: AsyncMigration {

    private func getOrCreateAIArtist(on database: Database) async throws -> Artist.IDValue {
        let artistName = "AI Composer"
        if let existingArtist = try await Artist.query(on: database)
            .filter(\.$name == artistName)
            .first() {
            return try existingArtist.requireID()
        } else {
            let newArtist = Artist(name: artistName, debutYear: 2024)
            try await newArtist.save(on: database)
            return try newArtist.requireID()
        }
    }

    func prepare(on database: Database) async throws {
        let aiSongsToProcess = try await AiSong.query(on: database).all()
        for aiSong in aiSongsToProcess {
            if let _ = try await Song.find(aiSong.songId, on: database) {
                continue
            }
            
            let title = aiSong.fileUrl.split(separator: "/").last?.split(separator: ".").first.map(String.init) ?? "Unknown AI Title \(aiSong.id?.uuidString ?? "")"
            let genre = "AI Generated"
            let artistID = try await getOrCreateAIArtist(on: database)
            let matchingSong = try await Song.query(on: database)
                .filter(\.$title == title)
                .filter(\.$artist.$id == artistID)
                .first()
            
            let songIDToLink: UUID
            if let foundSong = matchingSong {
                songIDToLink = try foundSong.requireID()
                if foundSong.isAIGenerated != true {
                    foundSong.isAIGenerated = true
                    try await foundSong.save(on: database)
                }
            } else {
                let newSong = Song(
                    title: title,
                    artistID: artistID,
                    genre: genre,
                    releaseDate: nil,
                    duration: nil,
                    isAIGenerated: true
                )
                try await newSong.save(on: database)
                songIDToLink = try newSong.requireID()
            }
            
            aiSong.songId = songIDToLink
            try await aiSong.update(on: database)
        }
    }

    func revert(on database: Database) async throws {
        let artistID = try await getOrCreateAIArtist(on: database)
        try await Song.query(on: database)
            .filter(\.$artist.$id == artistID)
            .filter(\.$isAIGenerated == true)
            .delete()
    }
}
