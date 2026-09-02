//
//  NetworkSession.swift
//  CTExp
//
//  Narrow protocol in front of URLSession so PhotoService can be tested
//  against a fake network layer (MockNetworkSession, added in Step 10)
//  instead of hitting the real network.
//

import Foundation

protocol NetworkSession {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {}
