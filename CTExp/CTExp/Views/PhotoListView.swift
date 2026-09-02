//
//  PhotoListView.swift
//  CTExp
//
//  Switches on PhotoListViewState (§7.3, §7.4) to show the loading
//  indicator, the table, or the error view with Retry.
//

import SwiftUI

struct PhotoListView: View {
    @StateObject private var viewModel = PhotoListViewModel()

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
