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

    func fetchPhotos() async throws -> [Photo] {
        try result.get()
    }
}
