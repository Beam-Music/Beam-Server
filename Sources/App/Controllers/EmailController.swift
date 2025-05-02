//
//  EmailController.swift
//  Beam-Music-Server
//
//  Created by freed on 10/15/24.
//

import Vapor
import SendGrid

struct EmailController {
    func sendVerificationEmail(req: Request, user: User, verificationCode: String) async throws {
        
        guard let sendGridClient = req.application.sendGridClient else {
            req.logger.error("SendGrid client not configured. Ensure it's initialized in configure.swift and the API key is set.")
            throw Abort(.internalServerError, reason: "SendGrid client not configured.")
        }
        
        let email = SendGridEmail(
            personalizations: [
                Personalization(to: [EmailAddress(email: user.email)])
            ],
            from: EmailAddress(email: "conner@modernlion.io"),
            subject: "Verify your email address",
            content: [
                ["type": "text/plain", "value": "Your verification code is: \(verificationCode). Enter this code in the app to verify your email."]
            ]
        )
        
        try await sendGridClient.send(email: email)
    }
}
