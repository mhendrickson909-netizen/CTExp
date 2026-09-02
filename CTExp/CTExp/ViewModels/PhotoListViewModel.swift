//
//  PhotoListViewModel.swift
//  CTExp
//
//  Owns PhotoListViewState and drives it via PhotoServiceProtocol (§8.1).
//  Depends on the protocol, not PhotoService directly, so tests can inject
//  MockPhotoService (added in Step 10).
//

import Foundation
import Combine

@MainActor
final class PhotoListViewModel: ObservableObject {
    /// Client-side display cap (§5) — JSONPlaceholder returns 5,000 records
    /// with no server-side pagination, so only the first N are shown.
    static let maxDisplayedItems = 100

    @Published private(set) var state: PhotoListViewState = .loading

    private let service: PhotoServiceProtocol

    init(service: PhotoServiceProtocol = PhotoService()) {
        self.service = service
    }

    /// Fetches (or re-fetches, on Retry) the photo list.
    func load() async {
        state = .loading
        do {
            let photos = try await service.fetchPhotos()
            state = .loaded(Array(photos.prefix(Self.maxDisplayedItems)))
        } catch {
            let message = (error as? PhotoServiceError)?.userFacingMessage
                ?? "Couldn't load photos. Check your connection and try again."
            state = .error(message: message)
        }
    }
}
