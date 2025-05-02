import Vapor
@preconcurrency import SendGrid

extension Application {
    struct SendGridKey: StorageKey {
        typealias Value = SendGridClient
    }
    
    var sendGridClient: SendGridClient? {
        get {
            self.storage[SendGridKey.self]
        }
        set {
            self.storage[SendGridKey.self] = newValue
        }
    }
} 