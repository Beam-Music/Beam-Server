//
//  File.swift
//  
//
//  Created by freed on 9/13/24.
//
import XCTVapor

final class AppTests: XCTestCase {
    var app: Application!
    
    override func setUpWithError() throws {
        app = Application(.testing)
    }
    
    override func tearDownWithError() throws {
        app.shutdown()
    }
    
    func configureApplication() async throws {
        try await configure(app)
    }
    
    func testExample() async throws {
        try await configureApplication()
        
        try await app.test(.GET, "hello") { res in
            XCTAssertEqual(res.status, .ok)
            XCTAssertEqual(res.body.string, "Hello, world!")
        }
    }
}
