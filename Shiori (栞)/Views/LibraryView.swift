import SwiftUI

extension Notification.Name {
    static let bookUpdated = Notification.Name("bookUpdated")
}

struct LibraryView: View {
    let bookType: BookType
    @State private var seriesData: [SeriesData] = []
    @State private var selectedSeries: SeriesData?
    @State private var showingConfirmation = false
    @State private var confirmationAction: (() -> Void)?
    
    var body: some View {
        NavigationView {
            VStack {
                if seriesData.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: bookTypeIcon)
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("No \(bookType.rawValue) Books")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Books you add to your library will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.customBackground)
                } else {
                    // Series list
                    List {
                        ForEach(seriesData, id: \.seriesName) { series in
                            SeriesRow(
                                series: series,
                                onTap: {
                                    selectedSeries = series
                                },
                                onMarkAllAsRead: { series in
                                    markAllAsRead(in: series)
                                },
                                onExport: { series in
                                    exportSeries(series)
                                }
                            )
                            .listRowBackground(Color.customBackground)
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.customBackground)
                }
            }
            .navigationTitle("\(bookType.rawValue) Books")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadSeries()
            }
            .fullScreenCover(item: $selectedSeries) { series in
                SeriesDetailView(series: series)
            }
            .onReceive(NotificationCenter.default.publisher(for: .bookUpdated)) { _ in
                loadSeries()
            }
            .alert("Are you sure?", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Mark All as Read", role: .destructive) {
                    confirmationAction?()
                }
            } message: {
                Text("This will mark all books in this series as finished.")
            }
            .background(Color.customBackground)
        }
    }
    
    private var bookTypeIcon: String {
        switch bookType {
        case .english: return "book"
        case .japanese: return "text.book.closed"
        case .manga: return "books.vertical.fill"
        }
    }
    
    private func loadSeries() {
        seriesData = DatabaseManager.shared.getSeries(by: bookType)
        print("DEBUG: LibraryView loaded \(seriesData.count) series for \(bookType.rawValue)")
    }
    
    private func markAllAsRead(in series: SeriesData) {
        confirmationAction = {
            let booksInSeries = DatabaseManager.shared.getBooksInSeries(series.seriesName, bookType: series.bookType)
            
            for book in booksInSeries {
                if book.readingStatus != .finished, let bookId = book.id {
                    _ = DatabaseManager.shared.updateReadingStatus(bookId: bookId, status: .finished)
                }
            }
            
            NotificationCenter.default.post(name: .bookUpdated, object: nil)
            loadSeries()
        }
        showingConfirmation = true
    }
    
    private func exportSeries(_ series: SeriesData) {
        let booksInSeries = DatabaseManager.shared.getBooksInSeries(series.seriesName, bookType: series.bookType)
        
        var exportText = "Series: \(series.seriesName)\n"
        exportText += "Type: \(series.bookType.rawValue)\n"
        exportText += "Total Books: \(series.bookCount)\n"
        exportText += "Completed: \(series.completedCount)\n\n"
        
        for book in booksInSeries {
            exportText += "• \(book.title)"
            if let author = book.author {
                exportText += " by \(author)"
            }
            exportText += " [\(book.readingStatus.rawValue)]"
            if let pages = book.pageCount {
                exportText += " - \(pages) pages"
            }
            exportText += "\n"
        }
        
        let activityController = UIActivityViewController(activityItems: [exportText], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityController, animated: true)
        }
    }
}

struct SeriesRow: View {
    let series: SeriesData
    let onTap: () -> Void
    let onMarkAllAsRead: (SeriesData) -> Void
    let onExport: (SeriesData) -> Void
    
    init(series: SeriesData, onTap: @escaping () -> Void, onMarkAllAsRead: @escaping (SeriesData) -> Void, onExport: @escaping (SeriesData) -> Void) {
        self.series = series
        self.onTap = onTap
        self.onMarkAllAsRead = onMarkAllAsRead
        self.onExport = onExport
        print("DEBUG: SeriesRow created with: '\(series.seriesName)', \(series.bookCount) books, status: '\(series.displayStatus)'")
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Series thumbnail (from last book)
            AsyncImage(url: URL(string: series.lastBookThumbnail.isEmpty ? "" : series.lastBookThumbnail)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 120)
                    .cornerRadius(8)
                    .shadow(radius: 2)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 120)
                    .cornerRadius(8)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "books.vertical")
                                .font(.title2)
                                .foregroundColor(.gray.opacity(0.8))
                            Text("No Image")
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                // Series title
                Text(series.seriesName)
                    .font(.headline)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Progress status
                Text(series.displayStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Last read date (if available)
                if let lastRead = series.lastReadDate {
                    Text("Last read: \(lastRead, formatter: dateFormatter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Spacer()
            
            // Series indicator
            VStack {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu(menuItems: {
            Button(action: {
                onTap()
            }) {
                Label("View Series", systemImage: "books.vertical.fill")
            }
            
            Button(action: {
                onMarkAllAsRead(series)
            }) {
                Label("Mark All as Read", systemImage: "checkmark.circle.fill")
            }
            
            Button(action: {
                onExport(series)
            }) {
                Label("Export Series", systemImage: "square.and.arrow.up")
            }
        }, preview: {
            SeriesPreviewView(series: series)
        })
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }
}

#Preview {
    LibraryView(bookType: .english)
}