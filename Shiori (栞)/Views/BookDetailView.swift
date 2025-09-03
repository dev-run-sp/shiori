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
    
    // No drag states needed for immediate dismiss
    
    
    var body: some View {
        ZStack {
            // Background view (actual search results)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(searchResults.indices, id: \.self) { index in
                        let searchBook = searchResults[index]
                        HStack(spacing: 20) {
                            AsyncImage(url: URL(string: searchBook.thumbnailUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 140)
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 140)
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(searchBook.title)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                if let author = searchBook.author {
                                    Text("Author: \(author)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let pageCount = searchBook.pageCount {
                                    Text("Pages: \(pageCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
            }
            .opacity(0.7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.customBackground)
            
            // Minimalistic large layout
            VStack(spacing: 20) {
                Spacer(minLength: 10)
                
                // Full width book thumbnail
                AsyncImage(url: URL(string: book.thumbnailUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.15))
                        .frame(maxWidth: .infinity, maxHeight: 320)
                        .cornerRadius(16)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "book.closed")
                                    .font(.system(size: 50, weight: .ultraLight))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("No Cover Image")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.6))
                            }
                        )
                }
                
                // Clean book info
                VStack(spacing: 12) {
                    Text(book.title)
                        .font(.title3)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                    
                    if let author = book.author {
                        Text(author)
                            .font(.subheadline)
                            .fontWeight(.regular)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 30)
                
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
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                Text("Add to Library")
                                    .font(.body)
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.caption)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(.blue)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    }
                } else {
                    // Saved book actions
                    VStack(spacing: 16) {
                        // Current status display and change status section
                        VStack(spacing: 12) {
                            HStack {
                                Text("Current Status:")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            // Current status card
                            HStack(spacing: 12) {
                                Image(systemName: readingStatus.icon)
                                    .font(.title2)
                                    .foregroundColor(readingStatus.color)
                                Text(readingStatus.rawValue)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(readingStatus.color.opacity(0.1))
                            .cornerRadius(10)
                            
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
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.body)
                                    Text("Change Status")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Series management section
                        VStack(spacing: 12) {
                            HStack {
                                Text("Series:")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            
                            // Current series display
                            HStack(spacing: 12) {
                                Image(systemName: "books.vertical")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text(seriesName.isEmpty ? "No Series" : seriesName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            
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
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.body)
                                    Text("Change Series")
                                        .font(.body)
                                        .fontWeight(.medium)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .foregroundColor(.purple)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Remove button
                        Button(action: {
                            removeBook()
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: "trash")
                                    .font(.body)
                                Text("Remove from Library")
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            .background(.red)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                Spacer(minLength: 20)
            }
            .background(Color.customBackground)
        }
        .navigationBarHidden(true)
        .highPriorityGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let translation = value.translation.height
                    if translation > 30 {
                        // Immediate dismiss as soon as threshold is met
                        withAnimation(.easeOut(duration: 0.3)) {
                            dismiss()
                        }
                    }
                }
        )
        .onAppear {
            resetViewState()
            checkIfBookSaved()
            loadExistingSeries()
        }
        .alert("Add New Series", isPresented: $showingNewSeriesAlert) {
            TextField("Series Name", text: $newSeriesName)
            Button("Add") {
                if !newSeriesName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    seriesName = newSeriesName.trimmingCharacters(in: .whitespacesAndNewlines)
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