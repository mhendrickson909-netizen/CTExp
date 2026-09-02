//
//  PhotoListViewModelTests.swift
//  CTExpTests
//
//  ViewModel layer tests (§10.2), driven entirely through MockPhotoService
//  (Step 10) — no PhotoService or network call happens in this file.
//
//  PhotoListViewModel is @MainActor, so its `state` property is
//  main-actor-isolated too. This whole test class is marked @MainActor to
//  read `state` directly rather than hopping actors on every assertion.
//

import XCTest
@testable import CTExp

@MainActor
final class PhotoListViewModelTests: XCTestCase {

    private func makePhotos(count: Int) -> [Photo] {
        (1...count).map { index in
            Photo(
                id: index,
                albumId: 1,
                title: "Photo \(index)",
                url: URL(string: "https://picsum.photos/seed/\(index)/600")!,
                thumbnailUrl: URL(string: "https://picsum.photos/seed/\(index)/150")!
            )
        }
    }

    func test_initialState_isLoading() {
        let viewModel = PhotoListViewModel(service: MockPhotoService())
        XCTAssertEqual(viewModel.state, .loading)
    }

    func test_load_underCap_returnsAllPhotosLoaded() async {
        let mockService = MockPhotoService()
        let photos = makePhotos(count: 10)
        mockService.result = .success(photos)
        let viewModel = PhotoListViewModel(service: mockService)

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded(photos))
    }

    func test_load_overCap_returnsOnlyFirstMaxDisplayedItems() async {
        let mockService = MockPhotoService()
        let photos = makePhotos(count: PhotoListViewModel.maxDisplayedItems + 50)
        mockService.result = .success(photos)
        let viewModel = PhotoListViewModel(service: mockService)

        await viewModel.load()

        guard case .loaded(let loadedPhotos) = viewModel.state else {
            XCTFail("Expected .loaded state")
            return
        }
        XCTAssertEqual(loadedPhotos.count, PhotoListViewModel.maxDisplayedItems)
        XCTAssertEqual(loadedPhotos, Array(photos.prefix(PhotoListViewModel.maxDisplayedItems)))
    }

    func test_load_networkError_resultsInErrorStateWithMessage() async {
        let mockService = MockPhotoService()
        mockService.result = .failure(.network(underlying: "offline"))
        let viewModel = PhotoListViewModel(service: mockService)

        await viewModel.load()

        guard case .error(let message) = viewModel.state else {
            XCTFail("Expected .error state")
            return
        }
        XCTAssertFalse(message.isEmpty)
    }

    func test_load_invalidResponseError_resultsInErrorStateWithMessage() async {
        let mockService = MockPhotoService()
        mockService.result = .failure(.invalidResponse(statusCode: 500))
        let viewModel = PhotoListViewModel(service: mockService)

        await viewModel.load()

        guard case .error(let message) = viewModel.state else {
            XCTFail("Expected .error state")
            return
        }
        XCTAssertFalse(message.isEmpty)
    }

    func test_load_decodingError_resultsInErrorStateWithMessage() async {
        let mockService = MockPhotoService()
        mockService.result = .failure(.decoding)
        let viewModel = PhotoListViewModel(service: mockService)

        await viewModel.load()

        guard case .error(let message) = viewModel.state else {
            XCTFail("Expected .error state")
            return
        }
        XCTAssertFalse(message.isEmpty)
    }

    func test_retry_afterFailureThenSuccess_reFetchesRatherThanReusingStaleState() async {
        let mockService = MockPhotoService()
        mockService.result = .failure(.network(underlying: "offline"))
        let viewModel = PhotoListViewModel(service: mockService)

        await viewModel.load()
        guard case .error = viewModel.state else {
            XCTFail("Expected .error state after first load()")
            return
        }

        let photos = makePhotos(count: 5)
        mockService.result = .success(photos)

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded(photos))
    }
}
