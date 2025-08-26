import SwiftUI

struct SeriesDetailView: View {
    let series: SeriesData
    @State private var booksInSeries: [SavedBook] = []
    @State private var selectedBook: Book?
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var bookToDelete: SavedBook?
    
    var body: some View {
        NavigationView {
            VStack {
                if booksInSeries.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("No Books in Series")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.customBackground)
                } else {
                    // Books list
                    List {
                        ForEach(booksInSeries, id: \.id) { savedBook in
                            SeriesBookRow(
                                savedBook: savedBook,
                                onTap: {
                                    selectedBook = savedBook.toBook()
                                },
                                onChangeStatus: { book in
                                    changeReadingStatus(for: book)
                                },
                                onRemove: { book in
                                    removeBookFromLibrary(book)
                                }
                            )
                            .listRowBackground(Color.customBackground)
                            .swipeActions(edge: .trailing) {
                                Button("Delete") {
                                    performSwipeDelete(savedBook)
                                }
                                .tint(.red)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.customBackground)
                }
            }
            .navigationTitle(series.seriesName)
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: Button("Done") {
                    dismiss()
                }
            )
            .onAppear {
                loadBooksInSeries()
            }
            .fullScreenCover(item: $selectedBook) { book in
                BookDetailView(book: book, searchResults: [])
            }
            .onReceive(NotificationCenter.default.publisher(for: .bookUpdated)) { _ in
                loadBooksInSeries()
            }
            .alert("Remove Book", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    if let book = bookToDelete {
                        performDelete(book)
                    }
                }
            } message: {
                Text("Are you sure you want to remove '\(bookToDelete?.title ?? "this book")' from your library?")
            }
            .background(Color.customBackground)
        }
    }
    
    private func loadBooksInSeries() {
        booksInSeries = DatabaseManager.shared.getBooksInSeries(series.seriesName, bookType: series.bookType)
    }
    
    private func deleteBook(_ savedBook: SavedBook) {
        guard let bookId = savedBook.id else { return }
        
        if DatabaseManager.shared.deleteBook(bookId: bookId) {
            loadBooksInSeries()
            NotificationCenter.default.post(name: .bookUpdated, object: nil)
        }
    }
    
    private func changeReadingStatus(for savedBook: SavedBook) {
        guard let bookId = savedBook.id else { return }
        
        let allCases = ReadingStatus.allCases
        if let currentIndex = allCases.firstIndex(of: savedBook.readingStatus) {
            let nextIndex = (currentIndex + 1) % allCases.count
            let newStatus = allCases[nextIndex]
            
            if DatabaseManager.shared.updateReadingStatus(bookId: bookId, status: newStatus) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    loadBooksInSeries()
                }
                NotificationCenter.default.post(name: .bookUpdated, object: nil)
            }
        }
    }
    
    private func removeBookFromLibrary(_ savedBook: SavedBook) {
        bookToDelete = savedBook
        showingDeleteConfirmation = true
    }
    
    private func performDelete(_ savedBook: SavedBook) {
        guard let bookId = savedBook.id else { return }
        
        // Find the book in the current list to get its index for smooth animation
        if let bookIndex = booksInSeries.firstIndex(where: { $0.id == bookId }) {
            // Smooth deletion animation
            withAnimation(.easeOut(duration: 0.4)) {
                booksInSeries.remove(at: bookIndex)
            }
            
            // Perform actual deletion after animation starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if DatabaseManager.shared.deleteBook(bookId: bookId) {
                    NotificationCenter.default.post(name: .bookUpdated, object: nil)
                } else {
                    // Revert animation if deletion failed
                    withAnimation(.easeIn(duration: 0.2)) {
                        loadBooksInSeries()
                    }
                }
            }
        }
    }
    
    private func performSwipeDelete(_ savedBook: SavedBook) {
        // Show the same confirmation modal as context menu
        bookToDelete = savedBook
        showingDeleteConfirmation = true
    }
}

struct SeriesBookRow: View {
    let savedBook: SavedBook
    let onTap: () -> Void
    let onChangeStatus: (SavedBook) -> Void
    let onRemove: (SavedBook) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Book thumbnail with context menu
            AsyncImage(url: URL(string: savedBook.thumbnailUrl)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 60, height: 90)
                    .cornerRadius(6)
                    .shadow(radius: 1)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 90)
                    .cornerRadius(6)
                    .overlay(
                        Image(systemName: "book.closed")
                            .foregroundColor(.gray.opacity(0.6))
                    )
            }
            .contextMenu(menuItems: {
                Button(action: {
                    onTap()
                }) {
                    Label("View Details", systemImage: "book.fill")
                }
                
                Button(action: {
                    onChangeStatus(savedBook)
                }) {
                    Label("Change Status", systemImage: "arrow.triangle.2.circlepath")
                }
                
                Button(action: {
                    onRemove(savedBook)
                }) {
                    Label("Remove from Library", systemImage: "trash")
                }
            }, preview: {
                BookPreviewView(book: savedBook.toBook())
            })
            
            VStack(alignment: .leading, spacing: 6) {
                // Title and author
                Text(savedBook.title)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                if let author = savedBook.author {
                    Text("by \(author)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Reading status badge
                HStack {
                    Image(systemName: savedBook.readingStatus.icon)
                        .font(.caption)
                    Text(savedBook.readingStatus.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(savedBook.readingStatus.color)
                .cornerRadius(12)
                
                // Reading duration (if finished)
                if savedBook.readingStatus == .finished,
                   let days = savedBook.readingDurationDays,
                   days > 0 {
                    Text("Read in \(days) day\(days == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    SeriesDetailView(
        series: SeriesData(
            seriesName: "Naruto",
            bookType: .manga,
            bookCount: 3,
            completedCount: 2,
            currentlyReadingCount: 1,
            lastBookThumbnail: "",
            lastReadDate: Date()
        )
    )
}