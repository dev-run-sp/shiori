import SwiftUI

struct SearchView: View {
    @State private var searchText = ""
    @State private var selectedPlatform = "Select Platform"
    @State private var results: [Book] = []
    @State private var isLoading = false
    @State private var currentPage = 1
    @State private var hasMorePages = true
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var searchHeaderVisible = true
    
    var body: some View {
        VStack(spacing: 0) {
            if searchHeaderVisible {
                searchHeaderView
                    .transition(.move(edge: .top).combined(with: .opacity))
                Divider()
            }
            searchResultsView
        }
        .background(Color.customBackground)
        .navigationTitle(searchHeaderVisible ? "Search Books" : "Search Results")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !searchHeaderVisible {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Show Search") {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            searchHeaderVisible = true
                        }
                    }
                }
            }
        }
        .alert("Error", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var searchHeaderView: some View {
        VStack(spacing: 16) {
            headerTitleView
            searchControlsView
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(Color.customBackground.opacity(0.95))
        .background(.ultraThinMaterial)
    }
    
    private var headerTitleView: some View {
        HStack {
            Text("Search Books")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    searchHeaderVisible = false
                }
            }) {
                Image(systemName: "chevron.up.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var searchControlsView: some View {
        VStack(spacing: 12) {
            searchBarView
            HStack(spacing: 12) {
                platformSelectorView
                    .frame(maxWidth: .infinity)
                searchButtonView
                    .frame(maxWidth: 120)
            }
        }
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search for books...", text: $searchText)
                .font(.body)
                .submitLabel(.search)
                .onSubmit {
                    Task {
                        await searchBooks(reset: true)
                    }
                }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var platformSelectorView: some View {
        Menu {
            Button("Bookmeter") {
                selectedPlatform = "Bookmeter"
            }
            Button("Goodreads") {
                selectedPlatform = "Goodreads"
            }
        } label: {
            HStack {
                Text(selectedPlatform == "Select Platform" ? "Choose Platform" : selectedPlatform)
                    .foregroundColor(selectedPlatform == "Select Platform" ? .primary : .white)
                Spacer()
                Image(systemName: "chevron.down")
                    .foregroundColor(selectedPlatform == "Select Platform" ? .primary : .white)
            }
            .padding()
            .background(platformSelectorBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var platformSelectorBackground: some View {
        Group {
            if selectedPlatform == "Select Platform" {
                Color.gray.opacity(0.1)
            } else {
                LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing)
            }
        }
    }
    
    private var searchButtonView: some View {
        Button(action: {
            Task {
                await searchBooks(reset: true)
            }
        }) {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Search")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(isSearchButtonDisabled)
    }
    
    private var isSearchButtonDisabled: Bool {
        isLoading || searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedPlatform == "Select Platform"
    }
    
    private var searchResultsView: some View {
        Group {
            if results.isEmpty && !isLoading {
                emptyStateView
            } else if !results.isEmpty {
                resultsListView
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            VStack(spacing: 16) {
                Image(systemName: "books.vertical")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.5))
                
                Text("No results yet")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                Text("Enter a search term and select a platform to find books")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            Spacer()
        }
    }
    
    private var resultsListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(results.indices, id: \.self) { index in
                        NavigationLink(destination: BookDetailView(book: results[index], searchResults: results)) {
                            bookRowView(for: results[index], at: index)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    if isLoading {
                        loadingIndicatorView
                    }
                }
                .padding()
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                if newPhase == .animating || newPhase == .interacting {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        searchHeaderVisible = false
                    }
                }
            }
        }
    }
    
    private func bookRowView(for book: Book, at index: Int) -> some View {
        HStack(spacing: 16) {
            bookCoverView(book: book)
            bookInfoView(book: book)
        }
        .padding()
        .background(Color.customBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .onAppear {
            if book.id == results.last?.id && !isLoading && hasMorePages {
                Task {
                    await searchBooks(reset: false)
                }
            }
        }
    }
    
    private func bookCoverView(book: Book) -> some View {
        AsyncImage(url: URL(string: book.thumbnailUrl)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fit)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .overlay(
                    Image(systemName: "book.closed")
                        .foregroundColor(.gray)
                )
        }
        .frame(width: 80, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
    }
    
    private func bookInfoView(book: Book) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            if let author = book.author {
                Text("by \(author)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            if let pageCount = book.pageCount {
                Text("\(pageCount) pages")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var loadingIndicatorView: some View {
        HStack {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .padding()
            Spacer()
        }
    }
    
    private func searchBooks(reset: Bool) async {
        if reset {
            currentPage = 1
            results = []
            hasMorePages = true
        }
        
        guard !isLoading && hasMorePages else { return }
        
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedSearchText.isEmpty else {
            await MainActor.run {
                alertMessage = "Please enter a search term"
                showingAlert = true
            }
            return
        }
        
        guard selectedPlatform != "Select Platform" else {
            await MainActor.run {
                alertMessage = "Please select a platform before searching"
                showingAlert = true
            }
            return
        }
        
        if selectedPlatform == "Goodreads" {
            await MainActor.run {
                alertMessage = "Goodreads search has not been implemented yet"
                showingAlert = true
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let newResults = try await BookmeterService.searchBooks(query: trimmedSearchText, page: currentPage)
            
            await MainActor.run {
                if newResults.isEmpty {
                    hasMorePages = false
                } else {
                    results.append(contentsOf: newResults)
                    currentPage += 1
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                let errorMessage: String
                if let urlError = error as? URLError {
                    switch urlError.code {
                    case .notConnectedToInternet:
                        errorMessage = "No internet connection available"
                    case .timedOut:
                        errorMessage = "Request timed out. Please try again."
                    case .cannotFindHost, .cannotConnectToHost:
                        errorMessage = "Cannot connect to server. Please check your connection."
                    default:
                        errorMessage = "Network error: \(error.localizedDescription)"
                    }
                } else {
                    errorMessage = "Search failed: \(error.localizedDescription)"
                }
                
                alertMessage = errorMessage
                showingAlert = true
                isLoading = false
            }
        }
    }
}