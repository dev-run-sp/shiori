import SwiftUI

struct SeriesDetailView: View {
    let series: SeriesData
    @State private var booksInSeries: [SavedBook] = []
    @State private var selectedBook: Book?
    @Environment(\.dismiss) private var dismiss
    
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
                            SeriesBookRow(savedBook: savedBook) {
                                selectedBook = savedBook.toBook()
                            }
                            .listRowBackground(Color.customBackground)
                            .swipeActions(edge: .trailing) {
                                Button("Delete") {
                                    deleteBook(savedBook)
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
}

struct SeriesBookRow: View {
    let savedBook: SavedBook
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Book thumbnail
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