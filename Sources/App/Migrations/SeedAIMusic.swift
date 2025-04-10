import Fluent
import Vapor

import Fluent
import Vapor

struct SeedAIMusic: Migration {
    func prepare(on database: Database) -> EventLoopFuture<Void> {
        let currentDate = Date()
        
        return Artist.query(on: database)
        
            .first()
            .flatMap { artist -> EventLoopFuture<Void> in
                guard let artist = artist else {
                    return database.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Required Artist not found in database"))
                }
                
                let validArtistID: UUID
                do {
                    validArtistID = try artist.requireID()
                } catch {
                    return database.eventLoop.makeFailedFuture(error)
                }
                
                let songs: [Song] = [
                    Song(
                        id: UUID(),
                        title: "sample1",
                        genre: "Electronic",
                        releaseDate: currentDate,
                        duration: 180,
                        artistID: validArtistID,
                        isAIGenerated: true
                    ),
                    Song(
                        id: UUID(),
                        title: "sample2",
                        genre: "Ambient",
                        releaseDate: currentDate,
                        duration: 210,
                        artistID: validArtistID,
                        isAIGenerated: true
                    )
                ]
                return songs.map { $0.save(on: database) }
                    .flatten(on: database.eventLoop)
                    .flatMap { _ -> EventLoopFuture<Void> in
                        guard let song1ID = songs[0].id, let song2ID = songs[1].id else {
                            return database.eventLoop.makeFailedFuture(Abort(.internalServerError, reason: "Failed to get saved Song IDs"))
                        }
                        
                        let aiSongs: [AiSong] = [
                            AiSong(
                                id: UUID(),
                                title: "AI Melody #1",
                                genre: "Electronic",
                                releaseDate: currentDate,
                                duration: 180,
                                isAIGenerated: true,
                                filePath: "/Public/sample/sample1.mp3",
                                songID: song1ID
                            ),
                            AiSong(
                                id: UUID(),
                                title: "AI Rhythm #2",
                                genre: "Ambient",
                                releaseDate: currentDate,
                                duration: 210,
                                isAIGenerated: true,
                                filePath: "/Public/sample/sample2.mp3",
                                songID: song2ID
                            )
                        ]
                        
                        
                        return aiSongs.map { aiSong -> EventLoopFuture<Void> in
                            return aiSong.save(on: database)
                        }
                        .flatten(on: database.eventLoop)
                    }
            }
    }
    
    func revert(on database: Database) -> EventLoopFuture<Void> {
        return AiSong.query(on: database)
            .filter(\.$isAIGenerated == true)
            .delete()
            .flatMap {
                return Song.query(on: database)
                    .filter(\.$isAIGenerated == true)
                    .delete()
            }
    }
}
