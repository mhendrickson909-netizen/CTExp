//
//  ContentView.swift
//  CTExp
//
//  Created by Benjamin Williams on 9/2/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            PhotoListView()
                .navigationTitle("Photos")
        }
    }
}

#Preview {
    ContentView()
}
