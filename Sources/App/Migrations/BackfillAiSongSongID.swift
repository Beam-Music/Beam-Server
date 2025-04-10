//
//  BackfillAiSongSongID.swift
//  Beam-Music-Server
//
//  Created by anonymous on 4/10/25.
//

import Fluent
import Vapor

struct BackfillAiSongSongID: AsyncMigration {
    func prepare(on database: Database) async throws {
        print("Running migration: BackfillAiSongSongID prepare...")
        
        // Use the correct filter syntax for nullable relationships
        let aiSongs = try await AiSong.query(on: database)
                                  .filter(\.$song.$id == .null)
                                  .all()
        
        for aiSong in aiSongs {
            if let matchingSong = try await Song.query(on: database)
                                      .filter(\.$title == aiSong.title)
                                      .first() {
                aiSong.$song.id = matchingSong.id
                try await aiSong.save(on: database)
                print("Backfilled song_id for AiSong: \(aiSong.title) with Song ID: \(matchingSong.id!)")
            } else {
                print("Warning: Could not find matching Song for AiSong title: \(aiSong.title)")
            }
        }
        
        print("Migration BackfillAiSongSongID prepare completed.")
    }

    func revert(on database: Database) async throws {
        print("Running migration: BackfillAiSongSongID revert...")
        // Your revert logic here
        print("Migration BackfillAiSongSongID revert completed.")
    }
}
