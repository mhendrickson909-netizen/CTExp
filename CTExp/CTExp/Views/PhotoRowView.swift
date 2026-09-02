//
//  PhotoRowView.swift
//  CTExp
//
//  A single row: thumbnail + title (§7.2), with accessibility label (§9.2).
//

import SwiftUI

struct PhotoRowView: View {
    let photo: Photo

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: photo.displayThumbnailURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                        .frame(width: 60, height: 60)
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipped()
                case .failure:
                    Image(systemName: "photo.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                        .frame(width: 60, height: 60)
                @unknown default:
                    Image(systemName: "photo")
                        .frame(width: 60, height: 60)
                }
            }
            .cornerRadius(6)

            Text(photo.title)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(photo.title)
    }
}

private extension Photo {
    /// JSONPlaceholder's sample `thumbnailUrl` points at via.placeholder.com,
    /// which has been permanently shut down (confirmed September 2026) — every
    /// request to it fails. This derives a stand-in thumbnail from Lorem
    /// Picsum instead, seeded by `id` so the same photo always renders the
    /// same image across launches. This is presentation-only: the model's
    /// own `thumbnailUrl` (§6) is left untouched and still reflects exactly
    /// what the API returned; only the row view's image source is swapped.
    var displayThumbnailURL: URL {
        URL(string: "https://picsum.photos/seed/\(id)/150")!
    }
}

#Preview {
    PhotoRowView(
        photo: Photo(
            id: 1,
            albumId: 1,
            title: "Sample photo title used for preview purposes",
            url: URL(string: "https://via.placeholder.com/600")!,
            thumbnailUrl: URL(string: "https://via.placeholder.com/150")!
        )
    )
}
