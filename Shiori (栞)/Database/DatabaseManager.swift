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
                    let thumbnailUrl: String = row["thumbnail_url"] ?? ""
                    let lastReadDateString: String? = row["last_read_date"]
                    
                    let dateFormatter = ISO8601DateFormatter()
                    let lastReadDate = lastReadDateString != nil ? dateFormatter.date(from: lastReadDateString!) : nil
                    
                    print("DEBUG: Found series: '\(seriesName)', \(bookCount) books, completed: \(completedCount), reading: \(currentlyReadingCount)")
                    
                    return SeriesData(
                        seriesName: seriesName,
                        bookType: bookType,
                        bookCount: bookCount,
                        completedCount: completedCount,
                        currentlyReadingCount: currentlyReadingCount,
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