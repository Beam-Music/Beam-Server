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
                // Ensure isAIGenerated is true if found
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
            guard let songIDValue = song.id else {
                print("Error: Song object \(song.title) is missing ID after save. Skipping AiSong creation.")
                continue
            }
            
            let fileName = song.title
            let fileExtension = ".mp3"
            let filePath = "/ai-songs/\(fileName)\(fileExtension)"
            
            let existingAiSong = try await AiSong.query(on: database)
                .filter(\.$song.$id == songIDValue)
                .first()
            
            if let actualExistingAiSong = existingAiSong {
                if actualExistingAiSong.fileUrl != filePath ||
                    actualExistingAiSong.title != song.title ||
                    actualExistingAiSong.duration != (song.duration ?? 0) {
                    
                    actualExistingAiSong.fileUrl = filePath
                    actualExistingAiSong.title = song.title
                    actualExistingAiSong.genre = song.genre
                    actualExistingAiSong.releaseDate = song.releaseDate
                    actualExistingAiSong.duration = song.duration ?? 0
                    actualExistingAiSong.isAiGenerated = song.isAIGenerated ?? true
                    
                    try await actualExistingAiSong.update(on: database)
                }
            } else {
                let aiSong = AiSong(
                    title: song.title,
                    genre: song.genre,
                    releaseDate: song.releaseDate,
                    duration: song.duration ?? 0,
                    isAiGenerated: song.isAIGenerated ?? true,
                    fileUrl: filePath,
                    songId: songIDValue
                )
                aiSongsToSave.append(aiSong)
            }
        }
        
        if !aiSongsToSave.isEmpty {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for aiSongInstance in aiSongsToSave {
                    group.addTask {
                        try await aiSongInstance.save(on: database)
                    }
                }
                try await group.waitForAll()
            }
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
        
        guard let artist = try await Artist.query(on: database).filter(\.$name == artistName).first() else {
            return
        }
        let artistID = try artist.requireID()
        
        songIDsToDelete = try await Song.query(on: database)
            .filter(\.$artist.$id == artistID)
            .filter(\.$title ~~ ["sample1", "sample2"])
            .all()
            .compactMap { $0.id }
        
        if songIDsToDelete.isEmpty {
        } else {
            if let playlist = try await RecommendPlaylist.query(on: database).filter(\.$name == playlistName).first() {
                let songsToDetach = try await Song.query(on: database).filter(\.$id ~~ songIDsToDelete).all()
                try await playlist.$songs.detach(songsToDetach, on: database)
            }
            
            let aiSongsDeleteQuery = AiSong.query(on: database)
                .filter(\.$song.$id ~~ songIDsToDelete) // Use \.$song.$id syntax
            try await aiSongsDeleteQuery.delete(force: true) // Perform deletion
            
            let songsDeleted = try await Song.query(on: database)
                .filter(\.$id ~~ songIDsToDelete)
                .delete(force: true)
        }
        
        let playlistDeleteQuery = RecommendPlaylist.query(on: database)
            .filter(\.$name == playlistName)
        try await playlistDeleteQuery.delete(force: true) // Perform deletion
    }
}
