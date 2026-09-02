//
//  PhotoServiceTests.swift
//  CTExpTests
//
//  Service layer tests (§10.2), driven entirely through MockNetworkSession
//  (Step 10) — no real network call happens in this file.
//

import XCTest
@testable import CTExp

final class PhotoServiceTests: XCTestCase {

    private let endpoint = URL(string: "https://jsonplaceholder.typicode.com/photos")!

    private func httpResponse(statusCode: Int) -> URLResponse {
        HTTPURLResponse(url: endpoint, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    }

    private let validJSON = """
    [
        {
            "albumId": 1,
            "id": 1,
            "title": "a sample title",
            "url": "https://picsum.photos/seed/1/600",
            "thumbnailUrl": "https://picsum.photos/seed/1/150"
        }
    ]
    """.data(using: .utf8)!

    func test_fetchPhotos_successResponse_returnsDecodedPhotos() async throws {
        let mockSession = MockNetworkSession()
        mockSession.result = .success((validJSON, httpResponse(statusCode: 200)))
        let service = PhotoService(session: mockSession)

        let photos = try await service.fetchPhotos()

        XCTAssertEqual(photos.count, 1)
        XCTAssertEqual(photos[0].id, 1)
        XCTAssertEqual(photos[0].title, "a sample title")
    }

    func test_fetchPhotos_httpErrorResponse_throwsInvalidResponse() async {
        let mockSession = MockNetworkSession()
        mockSession.result = .success((Data(), httpResponse(statusCode: 500)))
        let service = PhotoService(session: mockSession)

        do {
            _ = try await service.fetchPhotos()
            XCTFail("Expected fetchPhotos() to throw")
        } catch {
            XCTAssertEqual(error as? PhotoServiceError, .invalidResponse(statusCode: 500))
        }
    }

    func test_fetchPhotos_transportError_throwsNetwork() async {
        let injectedError = URLError(.notConnectedToInternet)
        let mockSession = MockNetworkSession()
        mockSession.result = .failure(injectedError)
        let service = PhotoService(session: mockSession)

        do {
            _ = try await service.fetchPhotos()
            XCTFail("Expected fetchPhotos() to throw")
        } catch {
            XCTAssertEqual(
                error as? PhotoServiceError,
                .network(underlying: injectedError.localizedDescription)
            )
        }
    }

    func test_fetchPhotos_malformedJSON_throwsDecoding() async {
        let malformedJSON = "{ this is not valid JSON".data(using: .utf8)!
        let mockSession = MockNetworkSession()
        mockSession.result = .success((malformedJSON, httpResponse(statusCode: 200)))
        let service = PhotoService(session: mockSession)

        do {
            _ = try await service.fetchPhotos()
            XCTFail("Expected fetchPhotos() to throw")
        } catch {
            XCTAssertEqual(error as? PhotoServiceError, .decoding)
        }
    }
}
