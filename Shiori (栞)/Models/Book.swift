import Foundation

struct Book: Identifiable {
    let id = UUID()
    let title: String
    let thumbnailUrl: String
    let author: String?
    let pageCount: Int?
}

extension Book {
    func toSavedBook(bookType: BookType, series: String? = nil) -> SavedBook {
        return SavedBook(
            id: nil,
            title: title,
            author: author,
            pageCount: pageCount,
            thumbnailUrl: thumbnailUrl,
            bookType: bookType,
            readingStatus: .wantToRead,
            series: series,
            dateAdded: Date(),
            dateStarted: nil,
            dateFinished: nil
        )
    }
}

extension SavedBook {
    func toBook() -> Book {
        return Book(
            title: title,
            thumbnailUrl: thumbnailUrl,
            author: author,
            pageCount: pageCount
        )
    }
}
