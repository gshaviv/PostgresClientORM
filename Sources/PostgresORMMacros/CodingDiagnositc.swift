//
//  CodingDiagnositc.swift
//
//
//  Created by Guy Shaviv on 26/10/2023.
//

import Foundation
import SwiftDiagnostics
import SwiftSyntax

public struct GeneratorDiagnostic: DiagnosticMessage, Error {
    /// The human-readable message.
    public let message: String
    /// The unique diagnostic id (should be the same for all diagnostics produced by the same codepath).
    public let diagnosticID: MessageID
    /// The diagnostic's severity.
    public let severity: DiagnosticSeverity

    /// Creates a new diagnostic message.
    public init(message: String, diagnosticID: GeneratorMessageID, severity: DiagnosticSeverity) {
        self.message = message
        self.diagnosticID = diagnosticID.id
        self.severity = severity
    }
}

public enum GeneratorMessageID {
    case general
    case arguments

    var id: MessageID {
        switch self {
        case .general:
            MessageID(domain: "CodingKeysGenerator", id: "general")
        case .arguments:
            MessageID(domain: "CodingKeysGenerator", id: "arguments")
        }
    }
}
