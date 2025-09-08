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

enum SortOption: String, CaseIterable {
    case alphabetical = "Alphabetical"
    case dateAdded = "Date Added"
    case readingStatus = "Reading Status"
    case author = "Author"
    case manual = "Manual"
    
    var icon: String {
        switch self {
        case .alphabetical: return "textformat.abc"
        case .dateAdded: return "calendar"
        case .readingStatus: return "checkmark.circle"
        case .author: return "person"
        case .manual: return "hand.draw"
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
    @State private var selectedSortOption: SortOption = .alphabetical
    @State private var manualBookOrder: [Int64] = []
    @State private var totalBooksInSeries = 0
    @State private var finishedBooksInSeries = 0
    @State private var currentlyReadingBooksInSeries = 0
    @State private var wantToReadBooksInSeries = 0
    @State private var showingHiddenBooksManager = false
    @State private var hiddenButtonTapCount = 0
    @State private var lastHiddenButtonTapTime = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                // Stats row
                if !allBooksInSeries.isEmpty {
                    seriesStatsRow
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
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
                
                // Sort dropdown
                if !booksInSeries.isEmpty {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Sort by")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        Menu {
                            ForEach(SortOption.allCases, id: \.self) { option in
                                Button(action: {
                                    selectedSortOption = option
                                    applySorting()
                                }) {
                                    HStack {
                                        Image(systemName: option.icon)
                                        Text(option.rawValue)
                                        Spacer()
                                        if selectedSortOption == option {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedSortOption.icon)
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text(selectedSortOption.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
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
                                onChangeStatus: { book, newStatus in
                                    changeReadingStatus(for: book, to: newStatus)
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
                        .onMove(perform: selectedSortOption == .manual ? moveBooks : nil)
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.customBackground)
                    
                    // Bulk actions toolbar
                    if isMultiSelectMode {
                        VStack(spacing: 0) {
                            Divider()
                            HStack(spacing: 16) {
                                Text("\(selectedBooks.count) selected")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Button(selectedBooks.count == booksInSeries.count ? "Deselect All" : "Select All") {
                                    if selectedBooks.count == booksInSeries.count {
                                        selectedBooks.removeAll()
                                    } else {
                                        selectedBooks = Set(booksInSeries.compactMap { $0.id })
                                    }
                                }
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                
                                Spacer()
                                
                                if !selectedBooks.isEmpty {
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
                leading: HStack {
                    Button("Done") {
                        dismiss()
                    }
                    Button(action: {
                        handleHiddenButtonTap()
                    }) {
                        Color.clear
                            .frame(width: 30, height: 30)
                            .contentShape(Rectangle())
                    }
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
                loadManualOrder()
            }
            .sheet(item: $selectedBook) { book in
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
            .sheet(isPresented: $showingHiddenBooksManager) {
                HiddenBooksManagerView(series: series)
            }
            .background(Color.customBackground)
        }
    }
    
    private var seriesStatsRow: some View {
        HStack(spacing: 12) {
            CompactStatView(title: "Total", value: totalBooksInSeries, color: .secondary)
            CompactStatView(title: "Want to Read", value: wantToReadBooksInSeries, color: .blue)
            CompactStatView(title: "Reading", value: currentlyReadingBooksInSeries, color: .orange)
            CompactStatView(title: "Finished", value: finishedBooksInSeries, color: .green)
            Spacer()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func loadBooksInSeries() {
        let allBooks = DatabaseManager.shared.getBooksInSeries(series.seriesName, bookType: series.bookType)
        let hiddenBookIds = getHiddenBookIds()
        allBooksInSeries = allBooks.filter { book in
            guard let bookId = book.id else { return true }
            return !hiddenBookIds.contains(bookId)
        }
        loadSeriesStats()
        applyFilter()
    }
    
    private func loadSeriesStats() {
        totalBooksInSeries = allBooksInSeries.count
        finishedBooksInSeries = allBooksInSeries.filter { $0.readingStatus == .finished }.count
        currentlyReadingBooksInSeries = allBooksInSeries.filter { $0.readingStatus == .currentlyReading }.count
        wantToReadBooksInSeries = allBooksInSeries.filter { $0.readingStatus == .wantToRead }.count
    }
    
    private func applyFilter() {
        if let targetStatus = selectedStatusFilter.readingStatus {
            booksInSeries = allBooksInSeries.filter { $0.readingStatus == targetStatus }
        } else {
            booksInSeries = allBooksInSeries
        }
        applySorting()
    }
    
    private func applySorting() {
        switch selectedSortOption {
        case .alphabetical:
            booksInSeries.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .dateAdded:
            booksInSeries.sort { $0.dateAdded > $1.dateAdded }
        case .readingStatus:
            let statusOrder: [ReadingStatus] = [.currentlyReading, .wantToRead, .finished]
            booksInSeries.sort { book1, book2 in
                let index1 = statusOrder.firstIndex(of: book1.readingStatus) ?? statusOrder.count
                let index2 = statusOrder.firstIndex(of: book2.readingStatus) ?? statusOrder.count
                if index1 != index2 {
                    return index1 < index2
                }
                return book1.title.localizedStandardCompare(book2.title) == .orderedAscending
            }
        case .author:
            booksInSeries.sort { book1, book2 in
                let author1 = book1.author ?? ""
                let author2 = book2.author ?? ""
                if author1 != author2 {
                    return author1.localizedCaseInsensitiveCompare(author2) == .orderedAscending
                }
                return book1.title.localizedStandardCompare(book2.title) == .orderedAscending
            }
        case .manual:
            if manualBookOrder.isEmpty {
                manualBookOrder = booksInSeries.compactMap { $0.id }
            } else {
                booksInSeries.sort { book1, book2 in
                    let id1 = book1.id ?? -1
                    let id2 = book2.id ?? -1
                    let index1 = manualBookOrder.firstIndex(of: id1) ?? Int.max
                    let index2 = manualBookOrder.firstIndex(of: id2) ?? Int.max
                    return index1 < index2
                }
            }
        }
    }
    
    private func moveBooks(from source: IndexSet, to destination: Int) {
        guard selectedSortOption == .manual else { return }
        
        var newOrder = booksInSeries
        newOrder.move(fromOffsets: source, toOffset: destination)
        booksInSeries = newOrder
        manualBookOrder = booksInSeries.compactMap { $0.id }
        saveManualOrder()
    }
    
    private func saveManualOrder() {
        UserDefaults.standard.set(manualBookOrder, forKey: "manualOrder_\(series.seriesName)_\(series.bookType.rawValue)")
    }
    
    private func loadManualOrder() {
        manualBookOrder = UserDefaults.standard.array(forKey: "manualOrder_\(series.seriesName)_\(series.bookType.rawValue)") as? [Int64] ?? []
    }
    
    private func getHiddenBookIds() -> Set<Int64> {
        let key = "hiddenBooks_\(series.seriesName)_\(series.bookType.rawValue)"
        let hiddenIds = UserDefaults.standard.array(forKey: key) as? [Int64] ?? []
        return Set(hiddenIds)
    }
    
    private func handleHiddenButtonTap() {
        let now = Date()
        if now.timeIntervalSince(lastHiddenButtonTapTime) < 2.0 {
            hiddenButtonTapCount += 1
        } else {
            hiddenButtonTapCount = 1
        }
        
        lastHiddenButtonTapTime = now
        
        if hiddenButtonTapCount >= 5 {
            showingHiddenBooksManager = true
            hiddenButtonTapCount = 0
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
    
    private func changeReadingStatus(for savedBook: SavedBook, to newStatus: ReadingStatus) {
        guard let bookId = savedBook.id else { return }
        
        if savedBook.readingStatus == newStatus {
            return // No change needed
        }
        
        if DatabaseManager.shared.updateReadingStatus(bookId: bookId, status: newStatus) {
            withAnimation(.easeInOut(duration: 0.3)) {
                loadBooksInSeries()
            }
            NotificationCenter.default.post(name: .bookUpdated, object: nil)
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
    let onChangeStatus: (SavedBook, ReadingStatus) -> Void
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
                    
                    Menu {
                        ForEach(ReadingStatus.allCases, id: \.self) { status in
                            Button {
                                onChangeStatus(savedBook, status)
                            } label: {
                                HStack {
                                    Image(systemName: status.icon)
                                    Text(status.rawValue)
                                    Spacer()
                                    if status == savedBook.readingStatus {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
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

struct HiddenBooksManagerView: View {
    let series: SeriesData
    @State private var allBooksInSeries: [SavedBook] = []
    @State private var hiddenBookIds: Set<Int64> = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if allBooksInSeries.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("No Books Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("This series appears to be empty")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("Visible Books") {
                            ForEach(visibleBooks, id: \.id) { book in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(book.title)
                                            .font(.headline)
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
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(book.readingStatus.color)
                                        .cornerRadius(8)
                                    }
                                    Spacer()
                                    Button("Hide") {
                                        hideBook(book)
                                    }
                                    .foregroundColor(.red)
                                }
                            }
                        }
                        
                        if !hiddenBooks.isEmpty {
                            Section("Hidden Books") {
                                ForEach(hiddenBooks, id: \.id) { book in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(book.title)
                                                .font(.headline)
                                                .foregroundColor(.secondary)
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
                                            }
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(book.readingStatus.color.opacity(0.6))
                                            .cornerRadius(8)
                                        }
                                        Spacer()
                                        Button("Show") {
                                            unhideBook(book)
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Book Visibility")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
            .onAppear {
                loadAllBooks()
            }
        }
    }
    
    private var visibleBooks: [SavedBook] {
        allBooksInSeries.filter { book in
            guard let bookId = book.id else { return true }
            return !hiddenBookIds.contains(bookId)
        }
    }
    
    private var hiddenBooks: [SavedBook] {
        allBooksInSeries.filter { book in
            guard let bookId = book.id else { return false }
            return hiddenBookIds.contains(bookId)
        }
    }
    
    private func loadAllBooks() {
        allBooksInSeries = DatabaseManager.shared.getBooksInSeries(series.seriesName, bookType: series.bookType)
        let key = "hiddenBooks_\(series.seriesName)_\(series.bookType.rawValue)"
        let hiddenIds = UserDefaults.standard.array(forKey: key) as? [Int64] ?? []
        hiddenBookIds = Set(hiddenIds)
    }
    
    private func hideBook(_ book: SavedBook) {
        guard let bookId = book.id else { return }
        hiddenBookIds.insert(bookId)
        saveHiddenBooks()
        NotificationCenter.default.post(name: .bookUpdated, object: nil)
    }
    
    private func unhideBook(_ book: SavedBook) {
        guard let bookId = book.id else { return }
        hiddenBookIds.remove(bookId)
        saveHiddenBooks()
        NotificationCenter.default.post(name: .bookUpdated, object: nil)
    }
    
    private func saveHiddenBooks() {
        let key = "hiddenBooks_\(series.seriesName)_\(series.bookType.rawValue)"
        UserDefaults.standard.set(Array(hiddenBookIds), forKey: key)
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