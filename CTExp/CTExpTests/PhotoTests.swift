//
//  PhotoTests.swift
//  CTExpTests
//
//  Model decoding tests (§10.2). Per the Step 2 testability table, Photo has
//  no external dependency and needs no protocol/mock — these tests exercise
//  its Decodable conformance directly against inline fixture JSON.
//

import XCTest
@testable import CTExp

final class PhotoTests: XCTestCase {

    private let validFixtureData = """
    [
        {
            "albumId": 1,
            "id": 1,
            "title": "accusamus beatae ad facilis cum similique qui sunt",
            "url": "https://picsum.photos/seed/1/600",
            "thumbnailUrl": "https://picsum.photos/seed/1/150"
        },
        {
            "albumId": 1,
            "id": 2,
            "title": "reprehenderit est deserunt velit ipsam",
            "url": "https://picsum.photos/seed/2/600",
            "thumbnailUrl": "https://picsum.photos/seed/2/150"
        }
    ]
    """.data(using: .utf8)!

    func test_decode_validFixture_producesExpectedPhotos() throws {
        let photos = try JSONDecoder().decode([Photo].self, from: validFixtureData)

        XCTAssertEqual(photos.count, 2)

        XCTAssertEqual(photos[0].id, 1)
        XCTAssertEqual(photos[0].albumId, 1)
        XCTAssertEqual(photos[0].title, "accusamus beatae ad facilis cum similique qui sunt")
        XCTAssertEqual(photos[0].url, URL(string: "https://picsum.photos/seed/1/600"))
        XCTAssertEqual(photos[0].thumbnailUrl, URL(string: "https://picsum.photos/seed/1/150"))

        XCTAssertEqual(photos[1].id, 2)
        XCTAssertEqual(photos[1].title, "reprehenderit est deserunt velit ipsam")
    }

    func test_decode_urlFields_decodeAsURL() throws {
        let photos = try JSONDecoder().decode([Photo].self, from: validFixtureData)

        // `url`/`thumbnailUrl` are declared as `URL` on Photo, so a successful
        // decode already proves they parsed as URL rather than String — this
        // also asserts they parsed into *valid, well-formed* URLs.
        XCTAssertEqual(photos[0].url.scheme, "https")
        XCTAssertEqual(photos[0].thumbnailUrl.scheme, "https")
    }

    func test_decode_missingRequiredField_throws() {
        let missingTitleData = """
        [
            {
                "albumId": 1,
                "id": 1,
                "url": "https://picsum.photos/seed/1/600",
                "thumbnailUrl": "https://picsum.photos/seed/1/150"
            }
        ]
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode([Photo].self, from: missingTitleData))
    }

    func test_decode_wrongTypeForField_throws() {
        let wrongIdTypeData = """
        [
            {
                "albumId": 1,
                "id": "not-a-number",
                "title": "bad id type",
                "url": "https://picsum.photos/seed/1/600",
                "thumbnailUrl": "https://picsum.photos/seed/1/150"
            }
        ]
        """.data(using: .utf8)!

        XCTAssertThrowsError(try JSONDecoder().decode([Photo].self, from: wrongIdTypeData))
    }
}
