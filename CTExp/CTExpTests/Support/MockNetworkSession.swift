//
//  MockNetworkSession.swift
//  CTExpTests
//
//  Test double for NetworkSession (Step 2's testability table). Lets
//  PhotoServiceTests (Step 11) drive PhotoService through success,
//  HTTP-error, transport-error, and decode-error paths without any real
//  networking.
//

import Foundation
@testable import CTExp

nonisolated final class MockNetworkSession: NetworkSession {
    var result: Result<(Data, URLResponse), Error> = .failure(URLError(.unknown))

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try result.get()
    }
}
