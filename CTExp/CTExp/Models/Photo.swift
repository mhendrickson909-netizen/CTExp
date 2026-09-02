//
//  Photo.swift
//  CTExp
//
//  Model for a single record returned by GET https://jsonplaceholder.typicode.com/photos
//

import Foundation

nonisolated struct Photo: Codable, Identifiable, Equatable {
    let id: Int
    let albumId: Int
    let title: String
    let url: URL
    let thumbnailUrl: URL

    enum CodingKeys: String, CodingKey {
        case id
        case albumId
        case title
        case url
        case thumbnailUrl
    }
}
