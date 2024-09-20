//
//  File.swift
//  
//
//  Created by freed on 9/19/24.
//

import Foundation
import JWT

struct AuthPayload: JWTPayload {
    
    typealias Payload = AuthPayload
    
    enum CodingKeys: String, CodingKey {
        case expiration = "exp"
        case userId = "uid"
    }
    
    var expiration: ExpirationClaim
    var userId: UUID
    
    func verify(using signer: JWTSigner) throws {
        try self.expiration.verifyNotExpired()
    }
    
}
