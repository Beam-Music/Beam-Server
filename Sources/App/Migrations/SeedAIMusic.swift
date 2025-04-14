import Fluent
import Vapor

struct SeedAIMusic: AsyncMigration {
    
    func prepare(on database: Database) async throws {
        let artistName = "AI Composer"
        let artistID: Artist.IDValue
        if let existingArtist = try await Artist.query(on: database)
            .filter(\.$name == artistName)
            .first() {
            artistID = try existingArtist.requireID()
        } else {
            let newArtist = Artist(name: artistName, debutYear: 2024)
            try await newArtist.save(on: database)
            artistID = try newArtist.requireID()
        }
        
        let songsData: [(title: String, genre: String?, duration: Int?)] = [
            ("sample1", "Electronic", 180),
            ("sample2", "Ambient", 240)
        ]
        
        var createdSongs: [Song] = []
        for data in songsData {
            let existingSong = try await Song.query(on: database)
                .filter(\.$title == data.title)
                .filter(\.$artist.$id == artistID)
                .first()
            if let foundSong = existingSong {
                if foundSong.isAIGenerated != true {
                    foundSong.isAIGenerated = true
                    try await foundSong.save(on: database)
                }
                createdSongs.append(foundSong)
            } else {
                let newSong = Song(
                    title: data.title,
                    artistID: artistID,
                    genre: data.genre ?? "Unknown Genre",
                    releaseDate: nil,
                    duration: data.duration,
                    isAIGenerated: true
                )
                try await newSong.save(on: database)
                createdSongs.append(newSong)
            }
        }
        
        var aiSongsToSave: [AiSong] = []
        for song in createdSongs {
            let fileName = song.title
            let fileExtension = ".mp3"
            let filePath = "/ai-songs/\(fileName)\(fileExtension)"
            
            let existingAiSong = try await AiSong.query(on: database)
                .filter(\.$songId == song.requireID())
                .first()
            
            if let actualExistingAiSong = existingAiSong {
                if actualExistingAiSong.fileUrl != filePath {
                    actualExistingAiSong.fileUrl = filePath
                    try await actualExistingAiSong.update(on: database)
                }
            } else {
                let aiSong = AiSong(
                    songId: try song.requireID(),
                    fileUrl: filePath
                )
                aiSongsToSave.append(aiSong)
            }
        }
        
        if !aiSongsToSave.isEmpty {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for aiSong in aiSongsToSave {
                    group.addTask { try await aiSong.save(on: database) }
                }
                try await group.waitForAll()
            }
        } else {
        }
        
        let targetPlaylistName = "AI Generated Hits"
        let targetPlaylist: RecommendPlaylist
        if let existingPlaylist = try await RecommendPlaylist.query(on: database)
            .filter(\.$name == targetPlaylistName)
            .first() {
            targetPlaylist = existingPlaylist
        } else {
            let newPlaylist = RecommendPlaylist(name: targetPlaylistName)
            try await newPlaylist.save(on: database)
            targetPlaylist = newPlaylist
        }
        
        try await withThrowingTaskGroup(of: Void.self) { group in
            for song in createdSongs {
                group.addTask {
                    let isAttached = try await targetPlaylist.$songs.isAttached(to: song, on: database)
                    if !isAttached {
                        try await targetPlaylist.$songs.attach(song, on: database)
                    } else {
                    }
                }
            }
            try await group.waitForAll()
        }
    }
    
    func revert(on database: Database) async throws {
        let artistName = "AI Composer"
        let playlistName = "AI Generated Hits"
        var songIDsToDelete: [UUID] = []
        
        if let artist = try await Artist.query(on: database).filter(\.$name == artistName).first() {
            songIDsToDelete = try await Song.query(on: database)
                .filter(\.$artist.$id == artist.requireID())
                .filter(\.$isAIGenerated == true)
                .all()
                .compactMap { $0.id }
        }
        
        if !songIDsToDelete.isEmpty {
            try await PlaylistSong.query(on: database)
                .filter(\.$song.$id ~~ songIDsToDelete)
                .delete()
            try await AiSong.query(on: database)
                .filter(\.$songId ~~ songIDsToDelete)
                .delete()
            
            try await Song.query(on: database)
                .filter(\.$id ~~ songIDsToDelete) // $id 사용
                .delete()
        } else {
            print("Seeder: No AI Song records found to delete for artist '\(artistName)'.")
        }
        
        try await RecommendPlaylist.query(on: database)
            .filter(\.$name == playlistName)
            .delete()
    }
}
