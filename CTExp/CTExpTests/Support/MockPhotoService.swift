//
//  MockPhotoService.swift
//  CTExpTests
//
//  Test double for PhotoServiceProtocol (Step 2's testability table). Lets
//  PhotoListViewModelTests (Step 12) drive PhotoListViewModel through
//  loading/loaded/error/retry without touching PhotoService or the network.
//

import Foundation
@testable import CTExp

nonisolated final class MockPhotoService: PhotoServiceProtocol {
    var result: Result<[Photo], PhotoServiceError> = .success([])

    /// When true, `fetchPhotos()` suspends indefinitely instead of
    /// returning `result`. Used by the Step 18 snapshot tests to keep a
    /// view model pinned in its initial `.loading` state for the entire
    /// snapshot capture, rather than racing PhotoListViewModel's `.task`
    /// against however fast a real `Result` would resolve.
    var neverResolves = false

    func fetchPhotos() async throws -> [Photo] {
        if neverResolves {
            try await Task.sleep(nanoseconds: .max)
        }
        return try result.get()
    }
}
