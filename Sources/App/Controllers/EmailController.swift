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
        let sendGridClient = req.application.sendgrid.client
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
        do {
            try await sendGridClient.send(email: email)
            req.logger.info("Verification email sent successfully to \(user.email)")
        } catch let error as SendGridError {
            req.logger.error("SendGrid API Error during verification email: \(error.localizedDescription)")
            req.logger.error("SendGrid - Errors: \(error.errors)")
            throw Abort(.internalServerError, reason: "Failed to send verification email. Errors: \(error.errors)")
        } catch {
            req.logger.error("Generic error sending verification email: \(error.localizedDescription)")
            throw Abort(.internalServerError, reason: "Failed to send verification email.")
        }
    }
}
