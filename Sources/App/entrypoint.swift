import Vapor
import Logging
import NIOCore
import NIOPosix
import Foundation

@main
enum Entrypoint {
    static func main() async throws {
        // Load .env file explicitly for Xcode
        loadEnvFile()
        
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)
        
        let app = try await Application.make(env)

        // This attempts to install NIO as the Swift Concurrency global executor.
        // You can enable it if you'd like to reduce the amount of context switching between NIO and Swift Concurrency.
        // Note: this has caused issues with some libraries that use `.wait()` and cleanly shutting down.
        // If enabled, you should be careful about calling async functions before this point as it can cause a ssertion failures.
        // let executorTakeoverSuccess = NIOSingletons.unsafeTryInstallSingletonPosixEventLoopGroupAsConcurrencyGlobalExecutor()
        // app.logger.debug("Tried to install SwiftNIO's EventLoopGroup as Swift's global concurrency executor", metadata: ["success": .stringConvertible(executorTakeoverSuccess)])
        
        do {
            try await configure(app)
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }
        try await app.execute()
        try await app.asyncShutdown()
    }
    
    /// Load .env file from project root directory
    static func loadEnvFile() {
        let fileManager = FileManager.default
        var envPath: String?
        
        // Try to find .env file starting from current working directory
        var currentPath = fileManager.currentDirectoryPath
        
        // If running from Xcode, try project root (go up from DerivedData)
        if currentPath.contains("DerivedData") {
            // Try to find project root by looking for Package.swift
            var searchPath = currentPath
            for _ in 0..<10 { // Search up to 10 levels
                let packageSwiftPath = (searchPath as NSString).appendingPathComponent("Package.swift")
                if fileManager.fileExists(atPath: packageSwiftPath) {
                    currentPath = searchPath
                    break
                }
                searchPath = (searchPath as NSString).deletingLastPathComponent
            }
        }
        
        // Try multiple possible locations
        let possiblePaths = [
            currentPath,
            (currentPath as NSString).appendingPathComponent(".."),
            (currentPath as NSString).appendingPathComponent("../.."),
            (currentPath as NSString).appendingPathComponent("../../.."),
        ]
        
        for path in possiblePaths {
            let resolvedPath = (path as NSString).standardizingPath
            let testPath = (resolvedPath as NSString).appendingPathComponent(".env")
            if fileManager.fileExists(atPath: testPath) {
                envPath = testPath
                break
            }
        }
        
        // Also try absolute path from project root
        if envPath == nil {
            let projectRoot = "/Users/anonymous/Desktop/Code/beamMusic/Beam-Server"
            let absolutePath = (projectRoot as NSString).appendingPathComponent(".env")
            if fileManager.fileExists(atPath: absolutePath) {
                envPath = absolutePath
            }
        }
        
        guard let envPath = envPath,
              let content = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            return
        }
        
        // Parse .env file and set environment variables
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                
                // Remove quotes if present
                if (value.hasPrefix("\"") && value.hasSuffix("\"")) || 
                   (value.hasPrefix("'") && value.hasSuffix("'")) {
                    value = String(value.dropFirst().dropLast())
                }
                
                // Only set if not already set (environment variables take precedence)
                if ProcessInfo.processInfo.environment[key] == nil {
                    setenv(key, value, 0)
                }
            }
        }
        
        // Force use local database by removing DATABASE_URL if DATABASE_HOST is set
        // This ensures we use DATABASE_HOST, DATABASE_PORT, etc. instead of DATABASE_URL
        if ProcessInfo.processInfo.environment["DATABASE_HOST"] != nil {
            unsetenv("DATABASE_URL")
            // Also set FORCE_LOCAL_DB to ensure configure.swift uses individual vars
            setenv("FORCE_LOCAL_DB", "true", 1)
        }
    }
}
