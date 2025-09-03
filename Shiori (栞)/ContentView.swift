//
//  ContentView.swift
//  My Test App
//
//  Created by Mohamed Mohamed on 8/18/25.
//

import SwiftUI


struct ContentView: View {
    private func searchBooks(reset: Bool) async {
        if reset {
            currentPage = 1
            results = []
            hasMorePages = true
            isInitialLoading = true
            showingSearchResults = true
        }
        
        guard !isLoading && hasMorePages else { return }
        
        if selectedPlatform == "Goodreads" {
            alertMessage = "Goodreads search has not been implemented yet"
            showingAlert = true
            isInitialLoading = false
            showingSearchResults = false
            return
        }
        
        guard selectedPlatform == "Bookmeter" else { return }
        
        isLoading = true
        
        do {
            let newResults = try await BookmeterService.searchBooks(query: searchText, page: currentPage)
            if newResults.isEmpty {
                hasMorePages = false
            } else {
                results.append(contentsOf: newResults)
                currentPage += 1
            }
        } catch {
            alertMessage = error.localizedDescription
            showingAlert = true
        }
        
        isLoading = false
        isInitialLoading = false
    }
    
    @State private var searchText = ""
    @State private var selectedPlatform = "Select Platform"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // Search results states
    @State private var results: [Book] = []
    @State private var isLoading = false
    @State private var isInitialLoading = false
    @State private var currentPage = 1
    @State private var hasMorePages = true
    @State private var showingSearchResults = false
    
    
    // Swipe back states
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Navigation states
    @State private var selectedBook: Book?
    
    // Quick add states - removed success alerts
    
    private func quickAddBook(_ book: Book, status: ReadingStatus) {
        // Default to English book type for quick add
        let result = DatabaseManager.shared.saveBook(book, bookType: .english, series: nil)
        
        if result.success {
            // Update the status if it's not the default "want to read"
            if status != .wantToRead {
                if let savedBook = DatabaseManager.shared.findBook(title: book.title, author: book.author) {
                    if DatabaseManager.shared.updateReadingStatus(bookId: savedBook.id!, status: status) {
                        NotificationCenter.default.post(name: .bookUpdated, object: nil)
                        return
                    }
                }
            }
            NotificationCenter.default.post(name: .bookUpdated, object: nil)
        } else {
            alertMessage = result.error ?? "Failed to add book"
            showingAlert = true
        }
    }

    var body: some View {
        TabView {
            // Home Tab
            ZStack {
                // Background view (previous screen) - only visible during search results
                if showingSearchResults {
                    VStack {
                        Spacer()
                        
                        // Initial Search View (same as main view)
                        VStack(spacing: 20) {
                            // Search Bar and Button
                            HStack {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(.gray)
                                    TextField("Search for books...", text: .constant(""))
                                        .textFieldStyle(CustomTextFieldStyle())
                                        .disabled(true)
                                }
                                
                                Button(action: {}) {
                                    Text("Search")
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                }
                                .disabled(true)
                            }
                            .padding(.horizontal)
                            
                            // Dropdown Menu
                            Menu {
                                Button("Goodreads") {}
                                Button("Bookmeter") {}
                            } label: {
                                HStack {
                                    Text("Select Platform")
                                    Image(systemName: "chevron.down")
                                }
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .disabled(true)
                        }
                        .frame(maxWidth: 300)
                        .padding()
                        .background(Color.customBackground)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                        .opacity(0.8)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.customBackground)
                }
                
                // Main content
                VStack {
                if !showingSearchResults {
                    Spacer()
                }
                
                if !showingSearchResults {
                    // Initial Search View
                    VStack(spacing: 20) {
                        // Search Bar and Button
                        HStack {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                TextField("Search for books...", text: $searchText)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            Button(action: {
                                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    alertMessage = "Please enter a search term"
                                    showingAlert = true
                                } else if selectedPlatform == "Select Platform" {
                                    alertMessage = "Please select a platform before searching"
                                    showingAlert = true
                                } else {
                                    Task {
                                        await searchBooks(reset: true)
                                    }
                                }
                            }) {
                                Text("Search")
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Dropdown Menu
                        Menu {
                            Button("Goodreads") {
                                selectedPlatform = "Goodreads"
                            }
                            Button("Bookmeter") {
                                selectedPlatform = "Bookmeter"
                            }
                        } label: {
                            HStack {
                                Text(selectedPlatform)
                                Image(systemName: "chevron.down")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: 300)
                    .padding()
                    .background(Color.customBackground)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                } else {
                    // Compact Search View
                    HStack(spacing: 12) {
                        Button(action: {
                            showingSearchResults = false
                            searchText = ""
                            selectedPlatform = "Select Platform"
                            results = []
                        }) {
                            Image(systemName: "arrow.left")
                                .foregroundColor(.blue)
                        }
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.gray)
                            TextField("Search for books...", text: $searchText)
                                .textFieldStyle(CustomTextFieldStyle())
                        }
                        
                        Button(action: {
                            if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                alertMessage = "Please enter a search term"
                                showingAlert = true
                            } else {
                                Task {
                                    await searchBooks(reset: true)
                                }
                            }
                        }) {
                            Text("Search")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.customBackground)
                    .shadow(radius: 2)
                }
                
                // Loading Indicator
                if isInitialLoading && showingSearchResults {
                    Spacer()
                    ProgressView()
                        .scaleEffect(2.0)
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .frame(width: 80, height: 80)
                        .background(Color.customBackground.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
                        .padding()
                    Spacer()
                }
                
                // Search Results
                if !results.isEmpty && !isInitialLoading && showingSearchResults {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(results.indices, id: \.self) { index in
                                let book = results[index]
                                HStack(spacing: 20) {
                                    AsyncImage(url: URL(string: book.thumbnailUrl)) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 100, height: 140)
                                            .cornerRadius(8)
                                            .shadow(radius: 2)
                                    } placeholder: {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 100, height: 140)
                                            .cornerRadius(8)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(book.title)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .lineLimit(3)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        if let author = book.author {
                                            Text("Author: \(author)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if let pageCount = book.pageCount {
                                            Text("Pages: \(pageCount)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .onTapGesture {
                                    selectedBook = book
                                }
                                .contextMenu(menuItems: {
                                    Button(action: {
                                        selectedBook = book
                                    }) {
                                        Label("View Details", systemImage: "book.fill")
                                    }
                                    
                                    Button(action: {
                                        quickAddBook(book, status: .wantToRead)
                                    }) {
                                        Label("Add to Want to Read", systemImage: "bookmark")
                                    }
                                    
                                    Button(action: {
                                        quickAddBook(book, status: .currentlyReading)
                                    }) {
                                        Label("Mark as Currently Reading", systemImage: "book.circle")
                                    }
                                    
                                    Button(action: {
                                        quickAddBook(book, status: .finished)
                                    }) {
                                        Label("Mark as Finished", systemImage: "checkmark.circle")
                                    }
                                }, preview: {
                                    BookPreviewView(book: book)
                                })
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                Divider()
                                .onAppear {
                                    if book.id == results.last?.id && !isLoading && hasMorePages {
                                        Task {
                                            await searchBooks(reset: false)
                                        }
                                    }
                                }
                            }
                            
                            if isLoading {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(1.5)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                        .frame(width: 60, height: 60)
                                        .background(Color.customBackground.opacity(0.9))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    Spacer()
                                }
                                .padding(.vertical, 20)
                            }
                        }
                    }
                    .disabled(isDragging)
                }
                
                Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.customBackground)
                .offset(x: showingSearchResults ? dragOffset : 0)
            }
            .gesture(
                showingSearchResults ? 
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        if translation > 0 {
                            dragOffset = translation
                            if translation > 20 {
                                isDragging = true
                            }
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let velocity = value.velocity.width
                        
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if translation > 120 || velocity > 500 {
                                dragOffset = UIScreen.main.bounds.width
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    showingSearchResults = false
                                    searchText = ""
                                    selectedPlatform = "Select Platform"
                                    results = []
                                    dragOffset = 0
                                    isDragging = false
                                }
                            } else {
                                dragOffset = 0
                                isDragging = false
                            }
                        }
                    }
                : nil
            )
            .alert("Error", isPresented: $showingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .fullScreenCover(item: $selectedBook) { book in
                BookDetailView(book: book, searchResults: results)
            }
            .tabItem {
                Image(systemName: "house")
                Text("Homepage")
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