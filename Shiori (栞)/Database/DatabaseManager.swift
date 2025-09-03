import Foundation
import GRDB

class DatabaseManager {
    static let shared = DatabaseManager()
    
    private var dbQueue: DatabaseQueue
    private let dbName = "shiori_books.sqlite"
    
    private init() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(dbName)
        
        print("DEBUG: Attempting to open database at: \(fileURL.path)")
        
        do {
            dbQueue = try DatabaseQueue(path: fileURL.path)
            print("DEBUG: Database opened successfully at: \(fileURL.path)")
            
            try dbQueue.write { db in
                try DatabaseSchema.createTables(in: db)
                print("DEBUG: Tables created successfully!")
            }
        } catch {
            fatalError("Unable to create database: \(error)")
        }
    }
    
    // MARK: - CRUD Operations
    
    func saveBook(_ book: Book, bookType: BookType, series: String? = nil) -> (success: Bool, error: String?) {
        print("DEBUG: saveBook called with:")
        print("  - Title: '\(book.title)'")
        print("  - Author: '\(book.author ?? "nil")'")
        print("  - BookType: '\(bookType.rawValue)'")
        print("  - Series: '\(series ?? "nil")'")
        print("  - ThumbnailURL: '\(book.thumbnailUrl)'")
        
        do {
            try dbQueue.write { db in
                var savedBook = SavedBook(
                    id: nil,
                    title: book.title,
                    author: book.author,
                    pageCount: book.pageCount,
                    thumbnailUrl: book.thumbnailUrl,
                    bookType: bookType,
                    readingStatus: .wantToRead,
                    series: series,
                    dateAdded: Date(),
                    dateStarted: nil,
                    dateFinished: nil
                )
                
                try savedBook.insert(db)
                print("DEBUG: Book saved successfully with ID: \(savedBook.id!)")
            }
            return (success: true, error: nil)
        } catch {
            let errorMessage = "Failed to save book: \(error.localizedDescription)"
            print("DEBUG: \(errorMessage)")
            return (success: false, error: errorMessage)
        }
    }
    
    func updateReadingStatus(bookId: Int64, status: ReadingStatus, customDate: Date? = nil) -> Bool {
        print("DEBUG: updateReadingStatus called for book ID: \(bookId), status: \(status.rawValue)")
        
        let dateToUse = customDate ?? Date()
        
        do {
            try dbQueue.write { db in
                var savedBook = try SavedBook.fetchOne(db, key: bookId)!
                savedBook.readingStatus = status
                
                switch status {
                case .currentlyReading:
                    savedBook.dateStarted = dateToUse
                    print("DEBUG: Setting date_started to: \(dateToUse)")
                case .finished:
                    savedBook.dateFinished = dateToUse
                    print("DEBUG: Setting date_finished to: \(dateToUse)")
                case .wantToRead:
                    savedBook.dateStarted = nil
                    savedBook.dateFinished = nil
                    print("DEBUG: Clearing dates for want to read")
                }
                
                try savedBook.update(db)
                print("DEBUG: Successfully updated reading status")
            }
            return true
        } catch {
            print("DEBUG: Failed to update reading status: \(error)")
            return false
        }
    }
    
    func updateBookSeries(bookId: Int64, series: String?) -> Bool {
        print("DEBUG: updateBookSeries called for book ID: \(bookId), series: \(series ?? "nil")")
        
        do {
            try dbQueue.write { db in
                var savedBook = try SavedBook.fetchOne(db, key: bookId)!
                savedBook.series = series
                try savedBook.update(db)
                print("DEBUG: Successfully updated book series")
            }
            return true
        } catch {
            print("DEBUG: Failed to update book series: \(error)")
            return false
        }
    }
    
    func getBooks(by bookType: BookType) -> [SavedBook] {
        print("DEBUG: getBooks() called for bookType: '\(bookType.rawValue)'")
        
        do {
            let books = try dbQueue.read { db in
                try SavedBook
                    .filter(SavedBook.Columns.bookType == bookType)
                    .order(SavedBook.Columns.dateAdded.desc)
                    .fetchAll(db)
            }
            print("DEBUG: Retrieved \(books.count) books for type \(bookType.rawValue)")
            return books
        } catch {
            print("DEBUG: Failed to retrieve books: \(error)")
            return []
        }
    }
    
    func findBook(title: String, author: String?) -> SavedBook? {
        print("DEBUG: findBook() called with title: '\(title)', author: '\(author ?? "nil")'")
        
        do {
            let book = try dbQueue.read { db in
                try SavedBook
                    .filter(SavedBook.Columns.title == title)
                    .filter(SavedBook.Columns.author == author || (SavedBook.Columns.author == nil && author == nil))
                    .fetchOne(db)
            }
            
            if let book = book {
                print("DEBUG: Found book with ID: \(book.id!)")
            } else {
                print("DEBUG: Book not found")
            }
            
            return book
        } catch {
            print("DEBUG: Failed to find book: \(error)")
            return nil
        }
    }
    
    func deleteBook(bookId: Int64) -> Bool {
        print("DEBUG: deleteBook() called for book ID: \(bookId)")
        
        do {
            try dbQueue.write { db in
                let deleted = try SavedBook.deleteOne(db, key: bookId)
                if deleted {
                    print("DEBUG: Book deleted successfully")
                } else {
                    print("DEBUG: Book not found for deletion")
                }
            }
            return true
        } catch {
            print("DEBUG: Failed to delete book: \(error)")
            return false
        }
    }
    
    func clearDatabase() -> Bool {
        print("DEBUG: clearDatabase() called")
        
        do {
            try dbQueue.write { db in
                try SavedBook.deleteAll(db)
                print("DEBUG: Database cleared successfully!")
            }
            return true
        } catch {
            print("DEBUG: Failed to clear database: \(error)")
            return false
        }
    }
    
    func bookExists(title: String, author: String?) -> Bool {
        do {
            return try dbQueue.read { db in
                if let author = author, !author.isEmpty {
                    // Check with both title and author
                    return try SavedBook
                        .filter(Column("title") == title && Column("author") == author)
                        .fetchCount(db) > 0
                } else {
                    // Check with title only
                    return try SavedBook
                        .filter(Column("title") == title)
                        .fetchCount(db) > 0
                }
            }
        } catch {
            print("DEBUG: Failed to check if book exists: \(error)")
            return false
        }
    }
    
    func getBook(byTitle title: String, author: String?) -> SavedBook? {
        do {
            return try dbQueue.read { db in
                if let author = author, !author.isEmpty {
                    // Search with both title and author
                    return try SavedBook
                        .filter(Column("title") == title && Column("author") == author)
                        .fetchOne(db)
                } else {
                    // Search with title only
                    return try SavedBook
                        .filter(Column("title") == title)
                        .fetchOne(db)
                }
            }
        } catch {
            print("DEBUG: Failed to get book: \(error)")
            return nil
        }
    }
    
    func getDatabasePath() -> String {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent(dbName)
        return fileURL.path
    }
    
    // MARK: - Series Operations
    
    func getSeries(by bookType: BookType) -> [SeriesData] {
        print("DEBUG: getSeries called for bookType: '\(bookType.rawValue)'")
        
        do {
            let seriesData = try dbQueue.read { db in
                let sql = """
                    SELECT 
                        COALESCE(series, 'Standalone Books') as series_name,
                        COUNT(*) as book_count,
                        SUM(CASE WHEN reading_status = 'Finished' THEN 1 ELSE 0 END) as completed_count,
                        SUM(CASE WHEN reading_status = 'Currently Reading' THEN 1 ELSE 0 END) as currently_reading_count,
                        SUM(CASE WHEN reading_status = 'Want to Read' THEN 1 ELSE 0 END) as want_to_read_count,
                        MAX(date_finished) as last_read_date,
                        MAX(thumbnail_url) as thumbnail_url
                    FROM saved_books
                    WHERE book_type = ? 
                    GROUP BY COALESCE(series, 'Standalone Books')
                    ORDER BY MAX(COALESCE(date_finished, date_started, date_added)) DESC;
                """
                
                print("DEBUG: getSeries SQL query:")
                print(sql)
                
                let rows = try Row.fetchAll(db, sql: sql, arguments: [bookType.rawValue])
                
                return rows.compactMap { row -> SeriesData? in
                    let seriesName: String = row["series_name"]
                    let bookCount: Int = row["book_count"]
                    let completedCount: Int = row["completed_count"]
                    let currentlyReadingCount: Int = row["currently_reading_count"]
                    let wantToReadCount: Int = row["want_to_read_count"]
                    let thumbnailUrl: String = row["thumbnail_url"] ?? ""
                    let lastReadDateString: String? = row["last_read_date"]
                    
                    let dateFormatter = ISO8601DateFormatter()
                    let lastReadDate = lastReadDateString != nil ? dateFormatter.date(from: lastReadDateString!) : nil
                    
                    print("DEBUG: Found series: '\(seriesName)', \(bookCount) books, completed: \(completedCount), reading: \(currentlyReadingCount), want to read: \(wantToReadCount)")
                    
                    return SeriesData(
                        seriesName: seriesName,
                        bookType: bookType,
                        bookCount: bookCount,
                        completedCount: completedCount,
                        currentlyReadingCount: currentlyReadingCount,
                        wantToReadCount: wantToReadCount,
                        lastBookThumbnail: thumbnailUrl,
                        lastReadDate: lastReadDate
                    )
                }
            }
            
            print("DEBUG: getSeries completed. Returning \(seriesData.count) series")
            return seriesData
        } catch {
            print("DEBUG: Failed to get series: \(error)")
            return []
        }
    }
    
    func getBooksInSeries(_ seriesName: String, bookType: BookType) -> [SavedBook] {
        print("DEBUG: getBooksInSeries() called with seriesName: '\(seriesName)', bookType: '\(bookType.rawValue)'")
        
        do {
            let books = try dbQueue.read { db in
                if seriesName == "Standalone Books" {
                    return try SavedBook
                        .filter(SavedBook.Columns.bookType == bookType)
                        .filter(SavedBook.Columns.series == nil || SavedBook.Columns.series == "")
                        .order(SavedBook.Columns.dateFinished.desc, SavedBook.Columns.dateStarted.desc, SavedBook.Columns.dateAdded.desc)
                        .fetchAll(db)
                } else {
                    return try SavedBook
                        .filter(SavedBook.Columns.bookType == bookType)
                        .filter(SavedBook.Columns.series == seriesName)
                        .order(SavedBook.Columns.dateFinished.desc, SavedBook.Columns.dateStarted.desc, SavedBook.Columns.dateAdded.desc)
                        .fetchAll(db)
                }
            }
            
            print("DEBUG: Retrieved \(books.count) books for series '\(seriesName)'")
            return books
        } catch {
            print("DEBUG: Failed to get books in series: \(error)")
            return []
        }
    }
    
    // MARK: - Export/Import Functions
    
    struct LibraryExport: Codable {
        let exportDate: Date
        let appVersion: String
        let books: [ExportedBook]
        
        struct ExportedBook: Codable {
            let title: String
            let author: String?
            let pageCount: Int?
            let thumbnailUrl: String
            let bookType: String
            let readingStatus: String
            let series: String?
            let dateAdded: Date
            let dateStarted: Date?
            let dateFinished: Date?
        }
    }
    
    func exportLibraryData() -> Result<String, Error> {
        do {
            let allBooks = try dbQueue.read { db in
                try SavedBook.order(SavedBook.Columns.dateAdded.desc).fetchAll(db)
            }
            
            let exportedBooks = allBooks.map { book in
                LibraryExport.ExportedBook(
                    title: book.title,
                    author: book.author,
                    pageCount: book.pageCount,
                    thumbnailUrl: book.thumbnailUrl,
                    bookType: book.bookType.rawValue,
                    readingStatus: book.readingStatus.rawValue,
                    series: book.series,
                    dateAdded: book.dateAdded,
                    dateStarted: book.dateStarted,
                    dateFinished: book.dateFinished
                )
            }
            
            let libraryExport = LibraryExport(
                exportDate: Date(),
                appVersion: "1.0.0",
                books: exportedBooks
            )
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            
            let jsonData = try encoder.encode(libraryExport)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            print("DEBUG: Successfully exported \(exportedBooks.count) books")
            return .success(jsonString)
            
        } catch {
            print("DEBUG: Failed to export library data: \(error)")
            return .failure(error)
        }
    }
    
    func importLibraryData(_ jsonString: String, replaceExisting: Bool = false) -> Result<ImportResult, Error> {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            guard let jsonData = jsonString.data(using: .utf8) else {
                return .failure(ImportError.invalidJSON)
            }
            
            let libraryExport = try decoder.decode(LibraryExport.self, from: jsonData)
            
            var importedCount = 0
            let skippedCount = 0
            var updatedCount = 0
            var errors: [String] = []
            
            try dbQueue.write { db in
                if replaceExisting {
                    try SavedBook.deleteAll(db)
                    print("DEBUG: Cleared existing library for replacement import")
                }
                
                for exportedBook in libraryExport.books {
                    do {
                        // Validate book type and reading status
                        guard let bookType = BookType(rawValue: exportedBook.bookType) else {
                            errors.append("Invalid book type '\(exportedBook.bookType)' for book '\(exportedBook.title)'")
                            continue
                        }
                        
                        guard let readingStatus = ReadingStatus(rawValue: exportedBook.readingStatus) else {
                            errors.append("Invalid reading status '\(exportedBook.readingStatus)' for book '\(exportedBook.title)'")
                            continue
                        }
                        
                        // Check if book already exists
                        let existingBook = try SavedBook
                            .filter(SavedBook.Columns.title == exportedBook.title && SavedBook.Columns.author == exportedBook.author)
                            .fetchOne(db)
                        
                        if let existing = existingBook {
                            if !replaceExisting {
                                // Update existing book
                                var updatedBook = existing
                                updatedBook.pageCount = exportedBook.pageCount
                                updatedBook.thumbnailUrl = exportedBook.thumbnailUrl
                                updatedBook.bookType = bookType
                                updatedBook.readingStatus = readingStatus
                                updatedBook.series = exportedBook.series
                                updatedBook.dateStarted = exportedBook.dateStarted
                                updatedBook.dateFinished = exportedBook.dateFinished
                                
                                try updatedBook.update(db)
                                updatedCount += 1
                                print("DEBUG: Updated existing book: \(exportedBook.title)")
                            }
                        } else {
                            // Create new book
                            var newBook = SavedBook(
                                id: nil,
                                title: exportedBook.title,
                                author: exportedBook.author,
                                pageCount: exportedBook.pageCount,
                                thumbnailUrl: exportedBook.thumbnailUrl,
                                bookType: bookType,
                                readingStatus: readingStatus,
                                series: exportedBook.series,
                                dateAdded: exportedBook.dateAdded,
                                dateStarted: exportedBook.dateStarted,
                                dateFinished: exportedBook.dateFinished
                            )
                            
                            try newBook.insert(db)
                            importedCount += 1
                            print("DEBUG: Imported new book: \(exportedBook.title)")
                        }
                        
                    } catch {
                        errors.append("Failed to import '\(exportedBook.title)': \(error.localizedDescription)")
                    }
                }
            }
            
            let result = ImportResult(
                totalBooks: libraryExport.books.count,
                importedCount: importedCount,
                updatedCount: updatedCount,
                skippedCount: skippedCount,
                errors: errors
            )
            
            print("DEBUG: Import completed - Imported: \(importedCount), Updated: \(updatedCount), Errors: \(errors.count)")
            return .success(result)
            
        } catch {
            print("DEBUG: Failed to import library data: \(error)")
            return .failure(error)
        }
    }
    
    struct ImportResult {
        let totalBooks: Int
        let importedCount: Int
        let updatedCount: Int
        let skippedCount: Int
        let errors: [String]
        
        var isSuccessful: Bool {
            return errors.isEmpty || (importedCount + updatedCount > 0)
        }
        
        var summary: String {
            var parts: [String] = []
            if importedCount > 0 { parts.append("\(importedCount) imported") }
            if updatedCount > 0 { parts.append("\(updatedCount) updated") }
            if skippedCount > 0 { parts.append("\(skippedCount) skipped") }
            if !errors.isEmpty { parts.append("\(errors.count) errors") }
            return parts.joined(separator: ", ")
        }
    }
    
    enum ImportError: Error {
        case invalidJSON
        case invalidData
        
        var localizedDescription: String {
            switch self {
            case .invalidJSON:
                return "Invalid JSON format"
            case .invalidData:
                return "Invalid data structure"
            }
        }
    }
    
    // MARK: - Debug Functions
    func printAllBooks() {
        print("DEBUG: printAllBooks() called")
        
        do {
            let books = try dbQueue.read { db in
                try SavedBook.order(SavedBook.Columns.dateAdded.desc).fetchAll(db)
            }
            
            print("\n=== DATABASE CONTENTS ===")
            print("ID | Title | Author | Pages | Thumbnail | Type | Status | Series | Added")
            print("--------------------------------------------------------------------")
            
            for book in books {
                let title = String(book.title.prefix(15))
                let author = String((book.author ?? "nil").prefix(10))
                let pageCount = book.pageCount?.description ?? "nil"
                let thumbnailStatus = book.thumbnailUrl.isEmpty ? "EMPTY" : "HAS_URL"
                let dateString = String(book.dateAdded.description.prefix(10))
                
                print("\(book.id!) | \(title) | \(author) | \(pageCount) | \(thumbnailStatus) | \(book.bookType.rawValue) | \(book.readingStatus.rawValue) | \(book.series ?? "nil") | \(dateString)")
            }
            print("=========================\n")
        } catch {
            print("DEBUG: Failed to print all books: \(error)")
        }
    }
}