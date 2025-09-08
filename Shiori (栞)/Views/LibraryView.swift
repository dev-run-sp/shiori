import SwiftUI

extension Notification.Name {
    static let bookUpdated = Notification.Name("bookUpdated")
    static let bookSelected = Notification.Name("bookSelected")
}

struct LibraryView: View {
    let bookType: BookType
    @State private var seriesData: [SeriesData] = []
    @State private var selectedSeries: SeriesData?
    @State private var showingConfirmation = false
    @State private var confirmationAction: (() -> Void)?
    @State private var showingBookmeterImport = false
    @State private var showingExportImport = false
    @State private var totalBooks = 0
    @State private var finishedBooks = 0
    @State private var currentlyReadingBooks = 0
    @State private var wantToReadBooks = 0
    @State private var showingHiddenSeriesManager = false
    @State private var titleTapCount = 0
    @State private var lastTitleTapTime = Date()
    
    var body: some View {
        NavigationView {
            VStack {
                // Stats row
                if !seriesData.isEmpty || totalBooks > 0 {
                    statsRow
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                
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
            .navigationBarItems(
                leading: Button(action: {
                    handleSecretTitleTap()
                }) {
                    Color.clear
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                },
                trailing: HStack(spacing: 16) {
                    Button(action: {
                        showingExportImport = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down.circle")
                                .font(.body)
                            Text("Export/Import")
                                .font(.subheadline)
                        }
                    }
                    
                    if bookType == .manga {
                        Button(action: {
                            showingBookmeterImport = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.body)
                                Text("Bookmeter")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
            )
            .onAppear {
                loadSeries()
            }
            .sheet(item: $selectedSeries) { series in
                SeriesDetailView(series: series)
            }
            .sheet(isPresented: $showingBookmeterImport) {
                BookmeterImportView()
            }
            .sheet(isPresented: $showingExportImport) {
                ExportImportView()
            }
            .sheet(isPresented: $showingHiddenSeriesManager) {
                HiddenSeriesManagerView(bookType: bookType)
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
    
    private var statsRow: some View {
        HStack(spacing: 12) {
            CompactStatView(title: "Total", value: totalBooks, color: .secondary)
            CompactStatView(title: "Want to Read", value: wantToReadBooks, color: .blue)
            CompactStatView(title: "Reading", value: currentlyReadingBooks, color: .orange)
            CompactStatView(title: "Finished", value: finishedBooks, color: .green)
            Spacer()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var bookTypeIcon: String {
        switch bookType {
        case .english: return "book"
        case .japanese: return "text.book.closed"
        case .manga: return "books.vertical.fill"
        }
    }
    
    private func loadSeries() {
        let allSeries = DatabaseManager.shared.getSeries(by: bookType)
        let hiddenSeriesNames = getHiddenSeriesNames()
        let visibleSeries = allSeries.filter { !hiddenSeriesNames.contains($0.seriesName) }
        
        // Recalculate series stats excluding hidden individual books
        seriesData = visibleSeries.map { series in
            let allBooksInSeries = DatabaseManager.shared.getBooksInSeries(series.seriesName, bookType: series.bookType)
            let hiddenBookIds = getHiddenBookIds(for: series.seriesName)
            let visibleBooksInSeries = allBooksInSeries.filter { book in
                guard let bookId = book.id else { return true }
                return !hiddenBookIds.contains(bookId)
            }
            
            let completedCount = visibleBooksInSeries.filter { $0.readingStatus == .finished }.count
            let currentlyReadingCount = visibleBooksInSeries.filter { $0.readingStatus == .currentlyReading }.count
            let wantToReadCount = visibleBooksInSeries.filter { $0.readingStatus == .wantToRead }.count
            
            return SeriesData(
                seriesName: series.seriesName,
                bookType: series.bookType,
                bookCount: visibleBooksInSeries.count,
                completedCount: completedCount,
                currentlyReadingCount: currentlyReadingCount,
                wantToReadCount: wantToReadCount,
                lastBookThumbnail: series.lastBookThumbnail,
                lastReadDate: series.lastReadDate
            )
        }
        
        loadStats()
        print("DEBUG: LibraryView loaded \(seriesData.count) series for \(bookType.rawValue)")
    }
    
    private func getHiddenBookIds(for seriesName: String) -> Set<Int64> {
        let key = "hiddenBooks_\(seriesName)_\(bookType.rawValue)"
        let hiddenIds = UserDefaults.standard.array(forKey: key) as? [Int64] ?? []
        return Set(hiddenIds)
    }
    
    private func loadStats() {
        let allBooks = DatabaseManager.shared.getBooks(by: bookType)
        let hiddenSeriesNames = getHiddenSeriesNames()
        let visibleBooks = allBooks.filter { book in
            // Filter out books from hidden series
            if hiddenSeriesNames.contains(book.series ?? "Standalone Books") {
                return false
            }
            
            // Filter out individually hidden books
            if let bookId = book.id {
                let hiddenBookIds = getHiddenBookIds(for: book.series ?? "Standalone Books")
                if hiddenBookIds.contains(bookId) {
                    return false
                }
            }
            
            return true
        }
        
        totalBooks = visibleBooks.count
        finishedBooks = visibleBooks.filter { $0.readingStatus == .finished }.count
        currentlyReadingBooks = visibleBooks.filter { $0.readingStatus == .currentlyReading }.count
        wantToReadBooks = visibleBooks.filter { $0.readingStatus == .wantToRead }.count
    }
    
    private func getHiddenSeriesNames() -> Set<String> {
        let key = "hiddenSeries_\(bookType.rawValue)"
        return Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
    
    private func handleSecretTitleTap() {
        let now = Date()
        if now.timeIntervalSince(lastTitleTapTime) < 2.0 {
            titleTapCount += 1
        } else {
            titleTapCount = 1
        }
        
        lastTitleTapTime = now
        
        if titleTapCount >= 5 {
            showingHiddenSeriesManager = true
            titleTapCount = 0
        }
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

struct CompactStatView: View {
    let title: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text("\(value)")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .fixedSize(horizontal: true, vertical: false)
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

struct HiddenSeriesManagerView: View {
    let bookType: BookType
    @State private var allSeries: [SeriesData] = []
    @State private var hiddenSeriesNames: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                if allSeries.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        Text("No Series Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Add some books to create series")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section("Visible Series") {
                            ForEach(visibleSeries, id: \.seriesName) { series in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(series.seriesName)
                                            .font(.headline)
                                        Text("\(series.bookCount) books")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("Hide") {
                                        hideSeries(series.seriesName)
                                    }
                                    .foregroundColor(.red)
                                }
                            }
                        }
                        
                        if !hiddenSeries.isEmpty {
                            Section("Hidden Series") {
                                ForEach(hiddenSeries, id: \.seriesName) { series in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(series.seriesName)
                                                .font(.headline)
                                                .foregroundColor(.secondary)
                                            Text("\(series.bookCount) books")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button("Show") {
                                            unhideSeries(series.seriesName)
                                        }
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Series Visibility")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
            .onAppear {
                loadAllSeries()
            }
        }
    }
    
    private var visibleSeries: [SeriesData] {
        allSeries.filter { !hiddenSeriesNames.contains($0.seriesName) }
    }
    
    private var hiddenSeries: [SeriesData] {
        allSeries.filter { hiddenSeriesNames.contains($0.seriesName) }
    }
    
    private func loadAllSeries() {
        allSeries = DatabaseManager.shared.getSeries(by: bookType)
        let key = "hiddenSeries_\(bookType.rawValue)"
        hiddenSeriesNames = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    }
    
    private func hideSeries(_ seriesName: String) {
        hiddenSeriesNames.insert(seriesName)
        saveHiddenSeries()
        NotificationCenter.default.post(name: .bookUpdated, object: nil)
    }
    
    private func unhideSeries(_ seriesName: String) {
        hiddenSeriesNames.remove(seriesName)
        saveHiddenSeries()
        NotificationCenter.default.post(name: .bookUpdated, object: nil)
    }
    
    private func saveHiddenSeries() {
        let key = "hiddenSeries_\(bookType.rawValue)"
        UserDefaults.standard.set(Array(hiddenSeriesNames), forKey: key)
    }
}

#Preview {
    LibraryView(bookType: .english)
}