//
//  PhotoServiceProtocol.swift
//  CTExp
//
//  The Service layer's public interface. PhotoListViewModel depends on
//  this protocol, not on PhotoService directly, so tests can inject
//  MockPhotoService (added in Step 10).
//

import Foundation

protocol PhotoServiceProtocol {
    func fetchPhotos() async throws -> [Photo]
}
