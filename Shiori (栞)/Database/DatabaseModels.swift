import Foundation
import SwiftUI
import GRDB

enum BookType: String, CaseIterable, Codable, DatabaseValueConvertible {
    case english = "English"
    case japanese = "Japanese" 
    case manga = "Manga"
}

enum ReadingStatus: String, CaseIterable, Codable, DatabaseValueConvertible {
    case wantToRead = "Want to Read"
    case currentlyReading = "Currently Reading"
    case finished = "Finished"
    
    var color: Color {
        switch self {
        case .wantToRead: return .blue
        case .currentlyReading: return .orange
        case .finished: return .green
        }
    }
    
    var icon: String {
        switch self {
        case .wantToRead: return "book"
        case .currentlyReading: return "book.fill"
        case .finished: return "checkmark.circle.fill"
        }
    }
    
    var buttonText: String {
        switch self {
        case .wantToRead: return "Start Reading"
        case .currentlyReading: return "Mark as Finished"
        case .finished: return "Move to Want to Read"
        }
    }
    
    var addButtonText: String {
        return "Add to Library"
    }
}

struct SavedBook: Codable, FetchableRecord, MutablePersistableRecord {
    var id: Int64?
    var title: String
    var author: String?
    var pageCount: Int?
    var thumbnailUrl: String
    var bookType: BookType
    var readingStatus: ReadingStatus
    var series: String?
    var dateAdded: Date
    var dateStarted: Date?
    var dateFinished: Date?
    
    // GRDB table configuration
    static let databaseTableName = "saved_books"
    
    // Define column names mapping Swift properties to database columns
    enum Columns: String, ColumnExpression {
        case id = "id"
        case title = "title"
        case author = "author"
        case pageCount = "page_count"
        case thumbnailUrl = "thumbnail_url"
        case bookType = "book_type"
        case readingStatus = "reading_status"
        case series = "series"
        case dateAdded = "date_added"
        case dateStarted = "date_started"
        case dateFinished = "date_finished"
    }
    
    // Custom encoding keys to map to database column names
    private enum CodingKeys: String, CodingKey {
        case id = "id"
        case title = "title"
        case author = "author"
        case pageCount = "page_count"
        case thumbnailUrl = "thumbnail_url"
        case bookType = "book_type"
        case readingStatus = "reading_status"
        case series = "series"
        case dateAdded = "date_added"
        case dateStarted = "date_started"
        case dateFinished = "date_finished"
    }
    
    // GRDB persistence
    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
    
    // Computed properties
    var readingDuration: TimeInterval? {
        guard let started = dateStarted, let finished = dateFinished else { return nil }
        return finished.timeIntervalSince(started)
    }
    
    var readingDurationDays: Int? {
        guard let duration = readingDuration else { return nil }
        return Int(duration / 86400) // Convert seconds to days
    }
}

struct SeriesData: Identifiable {
    var id: String { seriesName }
    let seriesName: String
    let bookType: BookType
    let bookCount: Int
    let completedCount: Int
    let currentlyReadingCount: Int
    let lastBookThumbnail: String
    let lastReadDate: Date?
    
    var displayStatus: String {
        if completedCount > 0 && currentlyReadingCount > 0 {
            return "\(completedCount) finished, \(currentlyReadingCount) reading"
        } else if completedCount > 0 {
            return "\(completedCount) finished"
        } else if currentlyReadingCount > 0 {
            return "\(currentlyReadingCount) reading"
        } else {
            return "\(bookCount) books"
        }
    }
}

// Database configuration for GRDB
struct DatabaseSchema {
    static func createTables(in db: Database) throws {
        try db.create(table: SavedBook.databaseTableName, ifNotExists: true) { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("title", .text).notNull()
            t.column("author", .text)
            t.column("pageCount", .integer)
            t.column("thumbnailUrl", .text).notNull()
            t.column("bookType", .text).notNull()
            t.column("readingStatus", .text).notNull()
            t.column("series", .text)
            t.column("dateAdded", .datetime).notNull()
            t.column("dateStarted", .datetime)
            t.column("dateFinished", .datetime)
        }
    }
}