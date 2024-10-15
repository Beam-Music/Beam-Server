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
        let sendGridClient = SendGridClient(httpClient: req.application.http.client.shared, apiKey: "")
        
        let email = SendGridEmail(
            personalizations: [
                Personalization(to: [EmailAddress(email: user.email)])
            ],
            from: EmailAddress(email: "support@beammusiccorp.xyz"),
            subject: "Verify your email address",
            content: [
                ["type": "text/plain", "value": "Your verification code is: \(verificationCode). Enter this code in the app to verify your email."]
            ]
        )
        
        try await sendGridClient.send(email: email)
    }
}
