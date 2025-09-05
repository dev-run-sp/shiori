import SwiftUI

struct BookDetailView: View {
    let book: Book
    let searchResults: [Book]
    @Environment(\.dismiss) private var dismiss
    @State private var showingSeriesOptions = false
    @State private var readingStatus: ReadingStatus = .wantToRead
    @State private var selectedBookType: BookType = .english
    @State private var seriesName: String = ""
    @State private var savedBook: SavedBook?
    @State private var isBookSaved: Bool = false
    @State private var existingSeries: [String] = []
    @State private var showingSeriesDropdown = false
    @State private var showingStatusDropdown = false
    @State private var showingNewSeriesAlert = false
    @State private var newSeriesName = ""
    @State private var showingDatePicker = false
    @State private var finishDate = Date()
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var customThumbnailUrl = ""
    @State private var showingCustomUrlInput = false
    @State private var imageRefreshId = UUID()
    
    // No drag states needed for immediate dismiss
    
    
    var body: some View {
        NavigationView {
            ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 20)
                    
                    // Large prominent book cover
                AsyncImage(url: URL(string: savedBook?.thumbnailUrl ?? book.thumbnailUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: min(280, UIScreen.main.bounds.width * 0.7), height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.3), radius: 25, x: 0, y: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                } placeholder: {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [Color.gray.opacity(0.2), Color.gray.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: min(280, UIScreen.main.bounds.width * 0.7), height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 60, weight: .ultraLight))
                                    .foregroundColor(.gray.opacity(0.6))
                                Text("No Cover Image")
                                    .font(.subheadline)
                                    .foregroundColor(.gray.opacity(0.7))
                                    .fontWeight(.medium)
                            }
                        )
                }
                .id(imageRefreshId)
                
                // Elegant book info
                VStack(spacing: 8) {
                    Text(book.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.primary)
                    
                    if let author = book.author {
                        Text("by \(author)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    if let pageCount = book.pageCount {
                        Text("\(pageCount) pages")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary.opacity(0.8))
                    }
                }
                .padding(.horizontal, 40)
                
                // Minimalist book type selection (if needed)
                if !isBookSaved {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            ForEach(BookType.allCases, id: \.self) { bookType in
                                Button(action: {
                                    selectedBookType = bookType
                                }) {
                                    Text(bookType.rawValue)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(selectedBookType == bookType ? Color.primary : Color.clear)
                                        .foregroundColor(selectedBookType == bookType ? Color(UIColor.systemBackground) : .primary)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                                        )
                                        .cornerRadius(20)
                                }
                            }
                        }
                        
                        // Series dropdown
                        Menu {
                            if existingSeries.isEmpty {
                                Button("Add New Series") {
                                    showingNewSeriesAlert = true
                                }
                            } else {
                                ForEach(existingSeries, id: \.self) { series in
                                    Button(series) {
                                        seriesName = series
                                    }
                                }
                                Divider()
                                Button("Add New Series") {
                                    showingNewSeriesAlert = true
                                }
                                Button("No Series") {
                                    seriesName = ""
                                }
                            }
                        } label: {
                            HStack {
                                Text(seriesName.isEmpty ? "Select Series" : seriesName)
                                    .font(.caption)
                                    .foregroundColor(seriesName.isEmpty ? .secondary : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 20)
                            .background(Color.gray.opacity(0.08))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Action buttons section
                if !isBookSaved {
                    // Compact dropdown for adding books
                    VStack(spacing: 12) {
                        Menu {
                            // Show all reading statuses when adding a book
                            ForEach(ReadingStatus.allCases, id: \.self) { status in
                                Button {
                                    addBookWithStatus(status)
                                } label: {
                                    HStack {
                                        Image(systemName: status.icon)
                                        Text(status.rawValue)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.callout)
                                Text("Add to Library")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 16)
                            .background(.blue)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 40)
                    }
                } else {
                    // Saved book actions
                    VStack(spacing: 16) {
                        // Compact status display
                        VStack(spacing: 8) {
                            HStack {
                                Text("Status:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            // Current status card
                            HStack(spacing: 8) {
                                Image(systemName: readingStatus.icon)
                                    .font(.callout)
                                    .foregroundColor(readingStatus.color)
                                Text(readingStatus.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(readingStatus.color.opacity(0.1))
                            .cornerRadius(8)
                            
                            // Change status dropdown
                            Menu {
                                ForEach(ReadingStatus.allCases, id: \.self) { status in
                                    Button {
                                        if status == readingStatus {
                                            // Already selected, do nothing or show feedback
                                            return
                                        } else if status == .finished {
                                            showingDatePicker = true
                                        } else {
                                            changeReadingStatus(to: status)
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: status.icon)
                                            Text(status.rawValue)
                                            Spacer()
                                            if status == readingStatus {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.callout)
                                    Text("Change Status")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        // Compact series management
                        VStack(spacing: 8) {
                            HStack {
                                Text("Series:")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            
                            // Current series display
                            HStack(spacing: 8) {
                                Image(systemName: "books.vertical")
                                    .font(.callout)
                                    .foregroundColor(.secondary)
                                Text(seriesName.isEmpty ? "No Series" : seriesName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            
                            // Change series dropdown
                            Menu {
                                if existingSeries.isEmpty {
                                    Button("Add New Series") {
                                        showingNewSeriesAlert = true
                                    }
                                } else {
                                    ForEach(existingSeries, id: \.self) { series in
                                        if series != seriesName {
                                            Button(series) {
                                                updateBookSeries(series)
                                            }
                                        }
                                    }
                                    Divider()
                                    Button("Add New Series") {
                                        showingNewSeriesAlert = true
                                    }
                                    if !seriesName.isEmpty {
                                        Button("Remove from Series") {
                                            updateBookSeries("")
                                        }
                                    }
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.callout)
                                    Text("Change Series")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Image(systemName: "chevron.down")
                                        .font(.caption2)
                                }
                                .foregroundColor(.purple)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        // Custom thumbnail URL button
                        Button(action: {
                            print("DEBUG: Custom Cover URL button tapped")
                            customThumbnailUrl = savedBook?.thumbnailUrl ?? ""
                            showingCustomUrlInput = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.callout)
                                Text("Change Cover URL")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.blue)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 40)
                        
                        // Compact remove button
                        Button(action: {
                            removeBook()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.callout)
                                Text("Remove")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(.red)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal, 40)
                    }
                }
                
                Spacer(minLength: 40)
            }
            .background(Color.customBackground)
            .navigationTitle("Book Details")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        }
        .onAppear {
            resetViewState()
            checkIfBookSaved()
            loadExistingSeries()
        }
        .alert("Add New Series", isPresented: $showingNewSeriesAlert) {
            TextField("Series Name", text: $newSeriesName)
            Button("Add") {
                if !newSeriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let trimmedSeriesName = newSeriesName.trimmingCharacters(in: .whitespacesAndNewlines)
                    updateBookSeries(trimmedSeriesName)
                    newSeriesName = ""
                }
            }
            Button("Cancel", role: .cancel) {
                newSeriesName = ""
            }
        } message: {
            Text("Enter the name for the new series")
        }
        .alert("Error Saving Book", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Change Cover URL", isPresented: $showingCustomUrlInput) {
            TextField("Enter image URL", text: $customThumbnailUrl)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Save") {
                updateThumbnailUrl()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Enter a new URL for the book cover image")
        }
        .sheet(isPresented: $showingDatePicker) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("When did you finish reading?")
                        .font(.headline)
                        .padding()
                    
                    DatePicker("Finish Date", selection: $finishDate, displayedComponents: [.date])
                        .datePickerStyle(.wheel)
                        .padding()
                    
                    Spacer()
                }
                .navigationTitle("Mark as Finished")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingDatePicker = false
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            markAsFinished()
                            showingDatePicker = false
                        }
                    }
                }
            }
        }
    }
    
    private func resetViewState() {
        // Reset all state variables to default values for each new book
        readingStatus = .wantToRead
        selectedBookType = .english
        seriesName = ""
        savedBook = nil
        isBookSaved = false
        existingSeries = []
    }
    
    private func loadExistingSeries() {
        // Get unique series names from all book types
        let allSeries = DatabaseManager.shared.getSeries(by: .english) +
                       DatabaseManager.shared.getSeries(by: .japanese) +
                       DatabaseManager.shared.getSeries(by: .manga)
        
        existingSeries = Array(Set(allSeries.compactMap { series in
            series.seriesName == "Standalone Books" ? nil : series.seriesName
        })).sorted()
    }
    
    private func checkIfBookSaved() {
        print("DEBUG: checkIfBookSaved() called for book: '\(book.title)'")
        
        savedBook = DatabaseManager.shared.findBook(title: book.title, author: book.author)
        if let savedBook = savedBook {
            print("DEBUG: Book found in database with ID: \(savedBook.id!)")
            isBookSaved = true
            readingStatus = savedBook.readingStatus
            selectedBookType = savedBook.bookType
            seriesName = savedBook.series ?? ""
        } else {
            print("DEBUG: Book not found in database")
            isBookSaved = false
            // Keep other values as they are for adding the book
        }
        
        print("DEBUG: checkIfBookSaved() result - isBookSaved: \(isBookSaved)")
    }
    
    private func addBookWithStatus(_ status: ReadingStatus) {
        let series = seriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : seriesName
        
        // Save book to database with specified status
        let result = DatabaseManager.shared.saveBook(book, bookType: selectedBookType, series: series)
        
        if result.success {
            // Update the UI state immediately
            isBookSaved = true
            readingStatus = status
            
            // Now update the status if it's not the default "want to read"
            if status != .wantToRead {
                checkIfBookSaved() // Get the saved book with ID
                if let savedBook = savedBook {
                    if DatabaseManager.shared.updateReadingStatus(bookId: savedBook.id!, status: status) {
                        readingStatus = status
                        checkIfBookSaved() // Refresh to get updated dates
                    }
                }
            } else {
                checkIfBookSaved() // Refresh the saved book data
            }
            NotificationCenter.default.post(name: .bookUpdated, object: nil)
        } else {
            // Show error modal
            errorMessage = result.error ?? "Unknown error occurred while saving book"
            showingErrorAlert = true
        }
    }
    
    private func cycleReadingStatus() {
        guard let savedBook = savedBook else { return }
        
        let allCases = ReadingStatus.allCases
        if let currentIndex = allCases.firstIndex(of: readingStatus) {
            let nextIndex = (currentIndex + 1) % allCases.count
            let newStatus = allCases[nextIndex]
            
            if DatabaseManager.shared.updateReadingStatus(bookId: savedBook.id!, status: newStatus) {
                readingStatus = newStatus
                checkIfBookSaved() // Refresh to get updated dates
                NotificationCenter.default.post(name: .bookUpdated, object: nil)
            }
        }
    }
    
    private func markAsFinished() {
        guard let savedBook = savedBook else { return }
        
        print("DEBUG: Marking book as finished with date: \(finishDate)")
        
        if DatabaseManager.shared.updateReadingStatus(bookId: savedBook.id!, status: .finished, customDate: finishDate) {
            readingStatus = .finished
            checkIfBookSaved() // Refresh to get updated dates
            NotificationCenter.default.post(name: .bookUpdated, object: nil)
        } else {
            print("DEBUG: Failed to mark book as finished")
        }
    }
    
    private func changeReadingStatus(to newStatus: ReadingStatus) {
        guard let savedBook = savedBook else { return }
        
        if DatabaseManager.shared.updateReadingStatus(bookId: savedBook.id!, status: newStatus) {
            readingStatus = newStatus
            checkIfBookSaved() // Refresh to get updated dates
            NotificationCenter.default.post(name: .bookUpdated, object: nil)
        }
    }
    
    private func updateBookSeries(_ newSeries: String) {
        guard let savedBook = savedBook else { return }
        
        let seriesValue = newSeries.isEmpty ? nil : newSeries
        if DatabaseManager.shared.updateBookSeries(bookId: savedBook.id!, series: seriesValue) {
            seriesName = newSeries
            checkIfBookSaved() // Refresh the saved book data
            NotificationCenter.default.post(name: .bookUpdated, object: nil)
        }
    }
    
    private func updateThumbnailUrl() {
        guard let savedBook = savedBook else { return }
        
        let urlValue = customThumbnailUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Basic URL validation
        if !urlValue.isEmpty {
            guard let url = URL(string: urlValue), 
                  url.scheme?.lowercased() == "https" || url.scheme?.lowercased() == "http" else {
                errorMessage = "Please enter a valid URL starting with http:// or https://"
                showingErrorAlert = true
                return
            }
        }
        
        if DatabaseManager.shared.updateThumbnailUrl(bookId: savedBook.id!, newUrl: urlValue) {
            checkIfBookSaved() // Refresh the saved book data
            imageRefreshId = UUID() // Force AsyncImage to refresh
            NotificationCenter.default.post(name: .bookUpdated, object: nil)
            print("DEBUG: Successfully updated thumbnail URL")
        } else {
            errorMessage = "Failed to update thumbnail URL"
            showingErrorAlert = true
            print("DEBUG: Failed to update thumbnail URL")
        }
    }
    
    private func removeBook() {
        guard let savedBook = savedBook else {
            print("DEBUG: removeBook() called but savedBook is nil")
            return
        }
        
        print("DEBUG: removeBook() called for book ID: \(savedBook.id!)")
        print("DEBUG: Current state - isBookSaved: \(isBookSaved)")
        
        if DatabaseManager.shared.deleteBook(bookId: savedBook.id!) {
            print("DEBUG: Book deleted successfully from database")
            
            // Update UI state to show "Add to Library" interface
            isBookSaved = false
            readingStatus = .wantToRead
            self.savedBook = nil
            
            print("DEBUG: Updated state - isBookSaved: \(isBookSaved), savedBook: nil")
            
            // Trigger refresh of library views
            NotificationCenter.default.post(name: .bookUpdated, object: nil)
        } else {
            print("DEBUG: Failed to delete book from database")
        }
    }
}

struct SeriesSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreateSeries = false
    @State private var newSeriesName = ""
    
    // Mock series data - you can replace with actual data later
    let existingSeries = ["Naruto Series", "One Piece Collection", "Studio Ghibli"]
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section("Existing Series") {
                        ForEach(existingSeries, id: \.self) { series in
                            Button(action: {
                                // Add to existing series
                                dismiss()
                            }) {
                                HStack {
                                    Text(series)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Create new series button
                Button(action: {
                    showingCreateSeries = true
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
            .navigationTitle("Add to Series")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
        }
        .alert("Create New Series", isPresented: $showingCreateSeries) {
            TextField("Series Name", text: $newSeriesName)
            Button("Create") {
                // Create new series logic
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

#Preview {
    BookDetailView(
        book: Book(
            title: "Sample Book Title That Might Be Long",
            thumbnailUrl: "https://example.com/book.jpg",
            author: "Sample Author",
            pageCount: 288
        ),
        searchResults: [
            Book(title: "Book 1", thumbnailUrl: "", author: "Author 1", pageCount: 200),
            Book(title: "Book 2", thumbnailUrl: "", author: "Author 2", pageCount: 300)
        ]
    )
}