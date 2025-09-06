import SwiftUI

struct HomePageView: View {
    @State private var libraryStats: LibraryStats?
    @State private var recentBooks: [SavedBook] = []
    @State private var currentlyReading: [SavedBook] = []
    @State private var selectedBook: Book?
    @State private var showingExportImportView = false
    
    var body: some View {
        NavigationStack {
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
                    
                    // Quick Actions Section
                    HStack(spacing: 12) {
                        NavigationLink(destination: SearchView()) {
                            CompactQuickActionCardView(
                                title: "Search",
                                icon: "magnifyingglass",
                                gradient: [.blue, .purple]
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        CompactQuickActionCard(
                            title: "Export",
                            icon: "arrow.up.doc",
                            gradient: [.green, .teal]
                        ) {
                            showingExportImportView = true
                        }
                    }
                    .padding(.horizontal)
                    
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
        .sheet(item: $selectedBook) { book in
            BookDetailView(book: book, searchResults: [])
        }
        .sheet(isPresented: $showingExportImportView) {
            ExportImportView()
        }
    }
    
    private func loadData() {
        // Load library statistics
        libraryStats = generateLibraryStats()
        
        // Load currently reading books (filtered by visible series)
        let englishCurrentlyReading = filterVisibleBooks(DatabaseManager.shared.getBooks(by: .english), bookType: .english).filter { $0.readingStatus == .currentlyReading }
        let japaneseCurrentlyReading = filterVisibleBooks(DatabaseManager.shared.getBooks(by: .japanese), bookType: .japanese).filter { $0.readingStatus == .currentlyReading }
        let mangaCurrentlyReading = filterVisibleBooks(DatabaseManager.shared.getBooks(by: .manga), bookType: .manga).filter { $0.readingStatus == .currentlyReading }
        
        let allCurrentlyReading = englishCurrentlyReading + japaneseCurrentlyReading + mangaCurrentlyReading
        currentlyReading = Array(allCurrentlyReading.prefix(5))
        
        // Load recent books (filtered by visible series)
        let englishBooks = filterVisibleBooks(DatabaseManager.shared.getBooks(by: .english), bookType: .english)
        let japaneseBooks = filterVisibleBooks(DatabaseManager.shared.getBooks(by: .japanese), bookType: .japanese)
        let mangaBooks = filterVisibleBooks(DatabaseManager.shared.getBooks(by: .manga), bookType: .manga)
        
        let allBooks = englishBooks + japaneseBooks + mangaBooks
        recentBooks = Array(allBooks
            .sorted { $0.dateAdded > $1.dateAdded }
            .prefix(6))
    }
    
    private func getHiddenSeriesNames(for bookType: BookType) -> Set<String> {
        let key = "hiddenSeries_\(bookType.rawValue)"
        return Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
    
    private func filterVisibleBooks(_ books: [SavedBook], bookType: BookType) -> [SavedBook] {
        let hiddenSeriesNames = getHiddenSeriesNames(for: bookType)
        return books.filter { book in
            !hiddenSeriesNames.contains(book.series ?? "Standalone Books")
        }
    }
    
    private func generateLibraryStats() -> LibraryStats {
        let englishBooks = filterVisibleBooks(DatabaseManager.shared.getBooks(by: .english), bookType: .english)
        let japaneseBooks = filterVisibleBooks(DatabaseManager.shared.getBooks(by: .japanese), bookType: .japanese)
        let mangaBooks = filterVisibleBooks(DatabaseManager.shared.getBooks(by: .manga), bookType: .manga)
        
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
            AsyncImage(url: {
                print("DEBUG: CurrentlyReadingCard thumbnail URL: '\(book.thumbnailUrl)'")
                let url = URL(string: book.thumbnailUrl)
                print("DEBUG: URL validation result: \(url?.absoluteString ?? "INVALID")")
                return url
            }()) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .failure(let error):
                    Rectangle()
                        .fill(Color.red.opacity(0.1))
                        .overlay(
                            VStack {
                                Image(systemName: "book.closed")
                                    .foregroundColor(.gray)
                                Text("Failed")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                Text("\(error.localizedDescription)")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                        )
                case .empty:
                    Rectangle()
                        .fill(Color.blue.opacity(0.1))
                        .overlay(
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                Text("Loading...")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                            }
                        )
                @unknown default:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "book.closed")
                                .foregroundColor(.gray)
                        )
                }
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

struct CompactQuickActionCard: View {
    let title: String
    let icon: String
    let gradient: [Color]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: gradient,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactQuickActionCardView: View {
    let title: String
    let icon: String
    let gradient: [Color]
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: gradient,
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: gradient.first?.opacity(0.3) ?? .clear, radius: 4, x: 0, y: 2)
    }
}

#Preview {
    HomePageView()
}