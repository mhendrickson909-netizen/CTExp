//
//  PhotoListViewState.swift
//  CTExp
//
//  Explicit state enum for the photo list (§7.5) — a single source of
//  truth the view switches on, rather than independent booleans/optionals.
//

import Foundation

enum PhotoListViewState: Equatable {
    case loading
    case loaded([Photo])
    case error(message: String)
}
