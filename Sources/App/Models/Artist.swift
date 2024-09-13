//
//  File.swift
//  
//
//  Created by freed on 9/12/24.
//
import Fluent
import Vapor

final class Artist: Model, Content {
    static let schema = "artists"

    @ID(key: .id)
    var id: UUID?

    @Field(key: "name")
    var name: String

    @Field(key: "debut_year")
    var debutYear: Int

    init() { }

    init(id: UUID? = nil, name: String, debutYear: Int) {
        self.id = id
        self.name = name
        self.debutYear = debutYear
    }
}



