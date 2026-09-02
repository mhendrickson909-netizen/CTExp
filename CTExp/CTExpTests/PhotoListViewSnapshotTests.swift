//
//  PhotoListViewSnapshotTests.swift
//  CTExpTests
//
//  Snapshot tests for PhotoListView's three states (§7.3/§7.4). This is a
//  visual-regression check on layout, not a re-test of PhotoListViewModel's
//  logic — that's already covered by PhotoListViewModelTests (Step 12).
//
//  PhotoListView/PhotoListViewModel are @MainActor, so this test class is
//  too (same reasoning as Step 12).
//

import XCTest
import SnapshotTesting
import SwiftUI
@testable import CTExp

@MainActor
final class PhotoListViewSnapshotTests: XCTestCase {

    private let layout: SnapshotTesting.SwiftUISnapshotLayout = .fixed(width: 390, height: 844)

    func test_loadedState_snapshot() async {
        let mockService = MockPhotoService()
        mockService.result = .success(PhotoFixtures.short)
        let viewModel = PhotoListViewModel(service: mockService)

        // Settle the view model deterministically *before* rendering,
        // rather than relying on PhotoListView's own `.task` to finish
        // racing against the snapshot capture.
        await viewModel.load()

        let view = PhotoListView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image(layout: layout))
    }

    func test_errorState_snapshot() async {
        let mockService = MockPhotoService()
        mockService.result = .failure(.network(underlying: "offline"))
        let viewModel = PhotoListViewModel(service: mockService)

        await viewModel.load()

        let view = PhotoListView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image(layout: layout))
    }

    func test_loadingState_snapshot() {
        let mockService = MockPhotoService()
        mockService.neverResolves = true
        let viewModel = PhotoListViewModel(service: mockService)

        // Deliberately not calling `await viewModel.load()` here — the
        // view's own `.task` will call it once rendered, but since
        // `neverResolves` means `fetchPhotos()` never returns, `state`
        // stays at its initial `.loading` value for the entire capture.
        let view = PhotoListView(viewModel: viewModel)

        assertSnapshot(of: view, as: .image(layout: layout))
    }
}
