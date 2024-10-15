//
//  String+Ext.swift
//  Beam-Music-Server
//
//  Created by freed on 10/15/24.
//

import Vapor

extension String {
    func removeAccents() -> String {
        let decomposed = self.decomposedStringWithCanonicalMapping
        return decomposed.components(separatedBy: CharacterSet.nonBaseCharacters).joined()
    }
    
    func removeWhitespaces(with string: String = "") -> String {
        self.replacingOccurrences(of: " ", with: string)
    }
    
    func validateEmail() throws {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let isValid = NSPredicate { input, _ in
            guard let input = input as? String else {
                return false
            }
            
            return input.range(of: regex, options: .regularExpression) != nil
        }.evaluate(with: self)
        
        guard isValid else {
            throw Abort(.badRequest, reason: "badRequest.email.invalid")
        }
    }
    
    func isValidEmail() -> Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let isValid = NSPredicate { input, _ in
            guard let input = input as? String else {
                return false
            }
            
            return input.range(of: regex, options: .regularExpression) != nil
        }.evaluate(with: self)
        
        return isValid
    }
}
