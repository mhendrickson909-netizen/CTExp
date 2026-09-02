//
//  PhotoServiceError.swift
//  CTExp
//
//  Error type surfaced by PhotoService. Cases carry enough detail to log
//  (§9.4) while staying Equatable so tests can assert on them directly.
//

import Foundation

nonisolated enum PhotoServiceError: Error, Equatable {
    case network(underlying: String)
    case invalidResponse(statusCode: Int)
    case decoding

    /// Short, non-technical message shown to the user (§7.4). Deliberately
    /// identical across cases — the distinction between them matters for
    /// logging and testing, not for differentiated UI copy.
    var userFacingMessage: String {
        "Couldn't load photos. Check your connection and try again."
    }
}
