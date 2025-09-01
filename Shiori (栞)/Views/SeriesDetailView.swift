import SwiftUI

enum BookStatusFilter: String, CaseIterable {
    case all = "All"
    case wantToRead = "Want to Read"
    case currentlyReading = "Currently Reading"
    case finished = "Finished"
    
    var icon: String {
        switch self {
        case .all: return "books.vertical"
        case .wantToRead: return "book"
        case .currentlyReading: return "book.fill"
        case .finished: return "checkmark.circle.fill"
        }
    }
    
    var readingStatus: ReadingStatus? {
        switch self {
        case .all: return nil
        case .wantToRead: return .wantToRead
        case .currentlyReading: return .currentlyReading
        case .finished: return .finished
        }
    }
}

struct SeriesDetailView: View {
    let series: SeriesData
    @State private var booksInSeries: [SavedBook] = []
    @State private var allBooksInSeries: [SavedBook] = []
    @State private var selectedBook: Book?
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var bookToDelete: SavedBook?
    @State private var existingSeries: [String] = []
    @State private var showingSeriesSelection = false
    @State private var showingNewSeriesAlert = false
    @State private var newSeriesName = ""
    @State private var bookToChangeSeries: SavedBook?
    @State private var isMultiSelectMode = false
    @State private var selectedBooks: Set<Int64> = []
    @State private var showingBulkSeriesSelection = false
    @State private var selectedStatusFilter: BookStatusFilter = .all
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter picker
                if !allBooksInSeries.isEmpty {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Filter by Status")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(BookStatusFilter.allCases, id: \.self) { filter in
                                    Button(action: {
                                        selectedStatusFilter = filter
                                        applyFilter()
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: filter.icon)
                                                .font(.caption)
                                            Text(filter.rawValue)
                                                .font(.subheadline)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(selectedStatusFilter == filter ? Color.blue : Color.gray.opacity(0.2))
                                        .foregroundColor(selectedStatusFilter == filter ? .white : .primary)
                                        .cornerRadius(16)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
                
                if booksInSeries.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: selectedStatusFilter.icon)
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text(emptyStateTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(emptyStateMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.customBackground)
                } else {
                    // Books list
                    List {
                        ForEach(booksInSeries, id: \.id) { savedBook in
                            SeriesBookRow(
                                savedBook: savedBook,
                                isMultiSelectMode: isMultiSelectMode,
                                isSelected: selectedBooks.contains(savedBook.id ?? -1),
                                onTap: {
                                    if isMultiSelectMode {
                                        toggleBookSelection(savedBook)
                                    } else {
                                        selectedBook = savedBook.toBook()
                                    }
                                },
                                onChangeStatus: { book in
                                    changeReadingStatus(for: book)
                                },
                                onChangeSeries: { book in
                                    changeBookSeries(book)
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
                    
                    // Bulk actions toolbar
                    if isMultiSelectMode && !selectedBooks.isEmpty {
                        VStack(spacing: 0) {
                            Divider()
                            HStack(spacing: 20) {
                                Text("\(selectedBooks.count) selected")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button("Change Series") {
                                    showingBulkSeriesSelection = true
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                
                                Button("Mark as Read") {
                                    bulkMarkAsRead()
                                }
                                .font(.subheadline)
                                .foregroundColor(.green)
                                
                                Button("Delete") {
                                    bulkDelete()
                                }
                                .font(.subheadline)
                                .foregroundColor(.red)
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground))
                        }
                    }
                }
            }
            .navigationTitle(series.seriesName)
            .navigationBarTitleDisplayMode(.large)
            .navigationBarItems(
                leading: Button("Done") {
                    dismiss()
                },
                trailing: HStack {
                    if isMultiSelectMode {
                        Button("Cancel") {
                            exitMultiSelectMode()
                        }
                    } else {
                        Button("Select") {
                            enterMultiSelectMode()
                        }
                    }
                }
            )
            .onAppear {
                loadBooksInSeries()
                loadExistingSeries()
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
            .alert("Add New Series", isPresented: $showingNewSeriesAlert) {
                TextField("Series Name", text: $newSeriesName)
                Button("Add") {
                    if !newSeriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        let seriesName = newSeriesName.trimmingCharacters(in: .whitespacesAndNewlines)
                        moveBookToSeries(seriesName)
                        newSeriesName = ""
                    }
                }
                Button("Cancel", role: .cancel) {
                    newSeriesName = ""
                }
            } message: {
                Text("Enter the name for the new series")
            }
            .sheet(isPresented: $showingSeriesSelection) {
                SeriesSelectionSheet(
                    existingSeries: existingSeries,
                    currentSeries: bookToChangeSeries?.series ?? "",
                    onSelectSeries: { selectedSeries in
                        moveBookToSeries(selectedSeries)
                    },
                    onCreateNewSeries: {
                        showingNewSeriesAlert = true
                    }
                )
            }
            .sheet(isPresented: $showingBulkSeriesSelection) {
                BulkSeriesSelectionSheet(
                    existingSeries: existingSeries,
                    selectedCount: selectedBooks.count,
                    onSelectSeries: { selectedSeries in
                        bulkMoveToSeries(selectedSeries)
                    },
                    onCreateNewSeries: {
                        showingNewSeriesAlert = true
                    }
                )
            }
            .background(Color.customBackground)
        }
    }
    
    private func loadBooksInSeries() {
        allBooksInSeries = DatabaseManager.shared.getBooksInSeries(series.seriesName, bookType: series.bookType)
        applyFilter()
    }
    
    private func applyFilter() {
        if let targetStatus = selectedStatusFilter.readingStatus {
            booksInSeries = allBooksInSeries.filter { $0.readingStatus == targetStatus }
        } else {
            booksInSeries = allBooksInSeries
        }
    }
    
    private var emptyStateTitle: String {
        if allBooksInSeries.isEmpty {
            return "No Books in Series"
        } else {
            switch selectedStatusFilter {
            case .all:
                return "No Books in Series"
            case .wantToRead:
                return "No Books to Read"
            case .currentlyReading:
                return "No Books Currently Reading"
            case .finished:
                return "No Finished Books"
            }
        }
    }
    
    private var emptyStateMessage: String {
        if allBooksInSeries.isEmpty {
            return "Add some books to this series to see them here"
        } else {
            switch selectedStatusFilter {
            case .all:
                return "Add some books to this series to see them here"
            case .wantToRead:
                return "No books in this series are marked as 'Want to Read'"
            case .currentlyReading:
                return "No books in this series are currently being read"
            case .finished:
                return "No books in this series have been finished yet"
            }
        }
    }
    
    private func loadExistingSeries() {
        let allSeries = DatabaseManager.shared.getSeries(by: .english) +
                       DatabaseManager.shared.getSeries(by: .japanese) +
                       DatabaseManager.shared.getSeries(by: .manga)
        
        existingSeries = Array(Set(allSeries.compactMap { series in
            series.seriesName == "Standalone Books" ? nil : series.seriesName
        })).sorted()
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
    
    private func changeBookSeries(_ savedBook: SavedBook) {
        bookToChangeSeries = savedBook
        showingSeriesSelection = true
    }
    
    private func moveBookToSeries(_ newSeriesName: String) {
        guard let book = bookToChangeSeries, let bookId = book.id else { return }
        
        let seriesValue = newSeriesName.isEmpty ? nil : newSeriesName
        if DatabaseManager.shared.updateBookSeries(bookId: bookId, series: seriesValue) {
            loadBooksInSeries()
            NotificationCenter.default.post(name: .bookUpdated, object: nil)
        }
        
        bookToChangeSeries = nil
        showingSeriesSelection = false
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
            _ = withAnimation(.easeOut(duration: 0.4)) {
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
    
    // MARK: - Multi-select Methods
    
    private func enterMultiSelectMode() {
        isMultiSelectMode = true
        selectedBooks.removeAll()
    }
    
    private func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedBooks.removeAll()
    }
    
    private func toggleBookSelection(_ savedBook: SavedBook) {
        guard let bookId = savedBook.id else { return }
        
        if selectedBooks.contains(bookId) {
            selectedBooks.remove(bookId)
        } else {
            selectedBooks.insert(bookId)
        }
    }
    
    private func bulkMoveToSeries(_ newSeriesName: String) {
        let seriesValue = newSeriesName.isEmpty ? nil : newSeriesName
        
        for bookId in selectedBooks {
            _ = DatabaseManager.shared.updateBookSeries(bookId: bookId, series: seriesValue)
        }
        
        loadBooksInSeries()
        NotificationCenter.default.post(name: .bookUpdated, object: nil)
        exitMultiSelectMode()
        showingBulkSeriesSelection = false
    }
    
    private func bulkMarkAsRead() {
        for bookId in selectedBooks {
            _ = DatabaseManager.shared.updateReadingStatus(bookId: bookId, status: .finished)
        }
        
        loadBooksInSeries()
        NotificationCenter.default.post(name: .bookUpdated, object: nil)
        exitMultiSelectMode()
    }
    
    private func bulkDelete() {
        for bookId in selectedBooks {
            _ = DatabaseManager.shared.deleteBook(bookId: bookId)
        }
        
        loadBooksInSeries()
        NotificationCenter.default.post(name: .bookUpdated, object: nil)
        exitMultiSelectMode()
    }
}

struct SeriesBookRow: View {
    let savedBook: SavedBook
    let isMultiSelectMode: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onChangeStatus: (SavedBook) -> Void
    let onChangeSeries: (SavedBook) -> Void
    let onRemove: (SavedBook) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Selection indicator in multi-select mode
            if isMultiSelectMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            
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
                if !isMultiSelectMode {
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
                        onChangeSeries(savedBook)
                    }) {
                        Label("Change Series", systemImage: "books.vertical")
                    }
                    
                    Button(action: {
                        onRemove(savedBook)
                    }) {
                        Label("Remove from Library", systemImage: "trash")
                    }
                }
            }, preview: {
                if !isMultiSelectMode {
                    BookPreviewView(book: savedBook.toBook())
                }
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

struct SeriesSelectionSheet: View {
    let existingSeries: [String]
    let currentSeries: String
    let onSelectSeries: (String) -> Void
    let onCreateNewSeries: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section("Move to Series") {
                        if existingSeries.isEmpty {
                            Text("No existing series")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(existingSeries.filter { $0 != currentSeries }, id: \.self) { series in
                                Button(action: {
                                    onSelectSeries(series)
                                    dismiss()
                                }) {
                                    HStack {
                                        Text(series)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.right.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        
                        Button(action: {
                            onSelectSeries("")
                            dismiss()
                        }) {
                            HStack {
                                Text("No Series (Standalone)")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Button(action: {
                    dismiss()
                    onCreateNewSeries()
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create New Series")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Change Series")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
        }
    }
}

struct BulkSeriesSelectionSheet: View {
    let existingSeries: [String]
    let selectedCount: Int
    let onSelectSeries: (String) -> Void
    let onCreateNewSeries: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section("Move \(selectedCount) book\(selectedCount == 1 ? "" : "s") to:") {
                        if existingSeries.isEmpty {
                            Text("No existing series")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(existingSeries, id: \.self) { series in
                                Button(action: {
                                    onSelectSeries(series)
                                    dismiss()
                                }) {
                                    HStack {
                                        Text(series)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: "arrow.right.circle")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        
                        Button(action: {
                            onSelectSeries("")
                            dismiss()
                        }) {
                            HStack {
                                Text("No Series (Standalone)")
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                
                Button(action: {
                    dismiss()
                    onCreateNewSeries()
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create New Series")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Move Books")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
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
            wantToReadCount: 0,
            lastBookThumbnail: "",
            lastReadDate: Date()
        )
    )
}