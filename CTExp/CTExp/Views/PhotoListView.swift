//
//  PhotoListView.swift
//  CTExp
//
//  Switches on PhotoListViewState (§7.3, §7.4) to show the loading
//  indicator, the table, or the error view with Retry.
//

import SwiftUI

struct PhotoListView: View {
    @StateObject private var viewModel: PhotoListViewModel

    /// Primary initializer — tests inject a view model already wired to
    /// MockPhotoService so state is deterministic for snapshotting.
    init(viewModel: PhotoListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    /// Convenience initializer used by the app (e.g. `PhotoListView()` in
    /// ContentView.swift). Constructs the real view model in the *body* of
    /// this init rather than as a default parameter value on the primary
    /// initializer — default parameter expressions in Swift always
    /// evaluate in a nonisolated context regardless of the enclosing
    /// declaration's own isolation, so putting `PhotoListViewModel()` in a
    /// default-argument position triggered an actor-isolation error
    /// calling into its @MainActor init. Calling it here, inside this
    /// init's body, sidesteps that rule entirely — this init is itself
    /// @MainActor (per the project's SWIFT_DEFAULT_ACTOR_ISOLATION
    /// setting), so a @MainActor init calling another @MainActor init is
    /// completely normal.
    init() {
        self.init(viewModel: PhotoListViewModel())
    }

    var body: some View {
        content
            .task {
                await viewModel.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView("Loading photos…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let photos):
            List(photos) { photo in
                PhotoRowView(photo: photo)
            }

        case .error(let message):
            VStack(spacing: 16) {
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Retry") {
                    Task {
                        await viewModel.load()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    PhotoListView()
}
