import Foundation

struct Book: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let thumbnailUrl: String
    let author: String?
    let pageCount: Int?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(title)
        hasher.combine(thumbnailUrl)
        hasher.combine(author)
        hasher.combine(pageCount)
    }
    
    static func == (lhs: Book, rhs: Book) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.thumbnailUrl == rhs.thumbnailUrl &&
        lhs.author == rhs.author &&
        lhs.pageCount == rhs.pageCount
    }
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
