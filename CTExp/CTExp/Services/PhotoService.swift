//
//  PhotoService.swift
//  CTExp
//
//  Fetches the photo list from JSONPlaceholder (§5) and decodes it into
//  [Photo], mapping any failure onto PhotoServiceError (§8.3).
//

import Foundation
import os

final class PhotoService: PhotoServiceProtocol {
    private static let endpoint = URL(string: "https://jsonplaceholder.typicode.com/photos")!
    private static let logger = Logger(subsystem: "mhen909.CTExp", category: "PhotoService")

    private let session: NetworkSession

    init(session: NetworkSession = URLSession.shared) {
        self.session = session
    }

    func fetchPhotos() async throws -> [Photo] {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: Self.endpoint)
        } catch {
            Self.logger.error("Network request failed: \(error.localizedDescription, privacy: .public)")
            throw PhotoServiceError.network(underlying: error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            Self.logger.error("Non-HTTP response received")
            throw PhotoServiceError.invalidResponse(statusCode: -1)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            Self.logger.error("Unexpected status code: \(httpResponse.statusCode, privacy: .public)")
            throw PhotoServiceError.invalidResponse(statusCode: httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode([Photo].self, from: data)
        } catch {
            Self.logger.error("Decoding failed: \(error.localizedDescription, privacy: .public)")
            throw PhotoServiceError.decoding
        }
    }
}
