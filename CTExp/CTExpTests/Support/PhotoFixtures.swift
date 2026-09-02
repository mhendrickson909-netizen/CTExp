//
//  PhotoFixtures.swift
//  CTExpTests
//
//  Deterministic Photo values shared across tests — snapshot tests
//  especially need fixed data rather than randomly generated fixtures,
//  since snapshots compare rendered images run to run.
//

import Foundation
@testable import CTExp

nonisolated enum PhotoFixtures {
    /// A short, representative list: two normal titles plus one deliberately
    /// long title so a `.loaded` snapshot exercises PhotoRowView's two-line
    /// title wrap, not just the happy-path short case.
    static let short: [Photo] = [
        Photo(
            id: 1,
            albumId: 1,
            title: "Mountain lake",
            url: URL(string: "https://picsum.photos/seed/1/600")!,
            thumbnailUrl: URL(string: "https://picsum.photos/seed/1/150")!
        ),
        Photo(
            id: 2,
            albumId: 1,
            title: "City skyline at dusk",
            url: URL(string: "https://picsum.photos/seed/2/600")!,
            thumbnailUrl: URL(string: "https://picsum.photos/seed/2/150")!
        ),
        Photo(
            id: 3,
            albumId: 1,
            title: "A much longer title to check how the row wraps across two lines",
            url: URL(string: "https://picsum.photos/seed/3/600")!,
            thumbnailUrl: URL(string: "https://picsum.photos/seed/3/150")!
        ),
    ]
}
