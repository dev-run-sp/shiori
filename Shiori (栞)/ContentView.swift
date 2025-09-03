//
//  ContentView.swift
//  My Test App
//
//  Created by Mohamed Mohamed on 8/18/25.
//

import SwiftUI


struct ContentView: View {

    var body: some View {
        TabView {
            // Home Tab
            HomePageView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Home")
                }

            // English Books Tab
            LibraryView(bookType: .english)
                .tabItem {
                    Image(systemName: "book")
                    Text("English Books")
                }

            // Japanese Books Tab
            LibraryView(bookType: .japanese)
                .tabItem {
                    Image(systemName: "text.book.closed")
                    Text("Japanese Books")
                }

            // Japanese Manga Tab
            LibraryView(bookType: .manga)
                .tabItem {
                    Image(systemName: "books.vertical.fill")
                    Text("Japanese Manga")
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}