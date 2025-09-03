import SwiftUI

struct HomePageView: View {
    @State private var libraryStats: LibraryStats?
    @State private var recentBooks: [SavedBook] = []
    @State private var currentlyReading: [SavedBook] = []
    @State private var selectedBook: Book?
    @State private var showingSearchView = false
    @State private var showingExportImportView = false
    
    // Search states
    @State private var searchText = ""
    @State private var selectedPlatform = "Select Platform"
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var results: [Book] = []
    @State private var isLoading = false
    @State private var isInitialLoading = false
    @State private var currentPage = 1
    @State private var hasMorePages = true
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Welcome Header
                    VStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("Welcome back")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text("Shiori")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                    
                    // Quick Stats Cards
                    if let stats = libraryStats {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Total Books",
                                    value: "\(stats.totalBooks)",
                                    icon: "books.vertical.fill",
                                    gradient: [.blue, .cyan]
                                )
                                
                                StatCard(
                                    title: "Finished",
                                    value: "\(stats.finishedBooks)",
                                    icon: "checkmark.circle.fill",
                                    gradient: [.green, .mint]
                                )
                            }
                            
                            HStack(spacing: 16) {
                                StatCard(
                                    title: "Reading",
                                    value: "\(stats.currentlyReading)",
                                    icon: "book.fill",
                                    gradient: [.orange, .yellow]
                                )
                                
                                StatCard(
                                    title: "Want to Read",
                                    value: "\(stats.wantToRead)",
                                    icon: "bookmark.fill",
                                    gradient: [.purple, .pink]
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Currently Reading Section
                    if !currentlyReading.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Currently Reading")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(Array(currentlyReading.prefix(5)), id: \.id) { book in
                                        CurrentlyReadingCard(book: book) {
                                            selectedBook = book.toBook()
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Recent Additions Section
                    if !recentBooks.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Recently Added")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                            }
                            .padding(.horizontal)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(Array(recentBooks.prefix(4)), id: \.id) { book in
                                    RecentBookRow(book: book) {
                                        selectedBook = book.toBook()
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // Quick Actions Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Actions")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            QuickActionCard(
                                title: "Search Books",
                                subtitle: "Find new books to read",
                                icon: "magnifyingglass",
                                gradient: [.blue, .purple]
                            ) {
                                showingSearchView = true
                            }
                            
                            QuickActionCard(
                                title: "Export Library",
                                subtitle: "Backup your collection",
                                icon: "arrow.up.doc",
                                gradient: [.green, .teal]
                            ) {
                                showingExportImportView = true
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.customBackground,
                        Color.customBackground.opacity(0.8),
                        Color.blue.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .refreshable {
                loadData()
            }
        }
        .onAppear {
            loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookUpdated)) { _ in
            loadData()
        }
        .sheet(isPresented: $showingSearchView) {
            NavigationView {
                VStack {
                    Text("Search functionality coming soon!")
                        .font(.headline)
                        .padding()
                    
                    Spacer()
                }
                .navigationTitle("Search Books")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Done") {
                    showingSearchView = false
                })
            }
        }
        .fullScreenCover(item: $selectedBook) { book in
            BookDetailView(book: book, searchResults: [])
        }
        .sheet(isPresented: $showingExportImportView) {
            ExportImportView()
        }
    }
    
    private func loadData() {
        // Load library statistics
        libraryStats = generateLibraryStats()
        
        // Load currently reading books
        let allCurrentlyReading = DatabaseManager.shared.getBooks(by: .english).filter { $0.readingStatus == .currentlyReading } +
                                 DatabaseManager.shared.getBooks(by: .japanese).filter { $0.readingStatus == .currentlyReading } +
                                 DatabaseManager.shared.getBooks(by: .manga).filter { $0.readingStatus == .currentlyReading }
        
        currentlyReading = Array(allCurrentlyReading.prefix(5))
        
        // Load recent books (last 10 added)
        let allBooks = DatabaseManager.shared.getBooks(by: .english) +
                      DatabaseManager.shared.getBooks(by: .japanese) +
                      DatabaseManager.shared.getBooks(by: .manga)
        
        recentBooks = Array(allBooks
            .sorted { $0.dateAdded > $1.dateAdded }
            .prefix(6))
    }
    
    private func generateLibraryStats() -> LibraryStats {
        let englishBooks = DatabaseManager.shared.getBooks(by: .english)
        let japaneseBooks = DatabaseManager.shared.getBooks(by: .japanese)
        let mangaBooks = DatabaseManager.shared.getBooks(by: .manga)
        
        let allBooks = englishBooks + japaneseBooks + mangaBooks
        
        return LibraryStats(
            totalBooks: allBooks.count,
            finishedBooks: allBooks.filter { $0.readingStatus == .finished }.count,
            currentlyReading: allBooks.filter { $0.readingStatus == .currentlyReading }.count,
            wantToRead: allBooks.filter { $0.readingStatus == .wantToRead }.count
        )
    }
    
}

struct LibraryStats {
    let totalBooks: Int
    let finishedBooks: Int
    let currentlyReading: Int
    let wantToRead: Int
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                Spacer()
            }
            
            Text(value)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 8, x: 0, y: 4)
    }
}

struct CurrentlyReadingCard: View {
    let book: SavedBook
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImage(url: URL(string: book.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "book.closed")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 100, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if let author = book.author {
                    Text(author)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 100, alignment: .leading)
        }
        .onTapGesture {
            onTap()
        }
    }
}

struct RecentBookRow: View {
    let book: SavedBook
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: book.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "book.closed")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 50, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                if let author = book.author {
                    Text("by \(author)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: book.readingStatus.icon)
                        .font(.caption2)
                    Text(book.readingStatus.rawValue)
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(book.readingStatus.color)
                .clipShape(Capsule())
            }
            
            Spacer()
            
            VStack {
                Text(book.bookType.rawValue)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
                
                Spacer()
            }
        }
        .padding()
        .background(Color.customBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let gradient: [Color]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                    Spacer()
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    HomePageView()
}