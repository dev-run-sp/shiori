import Foundation
import SwiftSoup

class BookmeterService {
    static let baseUrl = "https://bookmeter.com/search"
    static let userBooksUrl = "https://bookmeter.com/users"
    
    static func searchBooks(query: String, page: Int = 1) async throws -> [Book] {
        let searchParams = [
            "author": "",
            "keyword": query,
            "partial": "true",
            "sort": "recommended",
            "type": "japanese_v2",
            "page": "\(page)"
        ]
        
        var urlComponents = URLComponents(string: baseUrl)!
        urlComponents.queryItems = searchParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        
        return try parseHtml(html)
    }
    
    private static func parseHtml(_ html: String) throws -> [Book] {
        let document = try SwiftSoup.parse(html)
        
        // Find book elements using the correct selectors
        let bookElements = try document.select("li.group__book")
        
        return try bookElements.compactMap { element -> Book? in
            let thumbnailImg = try element.select("div.book__thumbnail img").first()
            let thumbnail = try thumbnailImg?.attr("src") ?? ""
            let title = try thumbnailImg?.attr("alt") ?? ""
            
            // Extract author from detail__authors ul class in book__detail
            let authorElement = try element.select("div.book__detail ul.detail__authors li").first()
            let author = try authorElement?.text().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Extract page count from detail__page div in book__detail
            let pageElement = try element.select("div.book__detail div.detail__page").first()
            let pageText = try pageElement?.text().trimmingCharacters(in: .whitespacesAndNewlines)
            let pageCount = extractPageCount(from: pageText)
            
            return Book(title: title, thumbnailUrl: thumbnail, author: author, pageCount: pageCount)
        }
    }
    
    private static func extractPageCount(from text: String?) -> Int? {
        guard let text = text else { return nil }
        
        // Extract numbers from page text (e.g., "288ページ" -> 288)
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
        for number in numbers {
            if let pageCount = Int(number), pageCount > 0 {
                return pageCount
            }
        }
        return nil
    }
    
    // MARK: - Import Functionality
    
    struct ImportProgress {
        let currentPage: Int
        let totalBooks: Int
        let newBooksAdded: Int
        let duplicatesSkipped: Int
    }
    
    static func importUserReadBooks(userId: String, progressCallback: @escaping (ImportProgress) -> Void) async throws -> ImportProgress {
        var allBooks: [Book] = []
        var currentPage = 1
        var totalNewBooks = 0
        var totalDuplicates = 0
        var hasMorePages = true
        
        print("DEBUG: Starting import for user ID: \(userId)")
        
        while hasMorePages {
            print("DEBUG: Fetching page \(currentPage)")
            
            let pageBooks = try await fetchUserReadBooksPage(userId: userId, page: currentPage)
            
            if pageBooks.isEmpty {
                print("DEBUG: No books found on page \(currentPage), stopping")
                hasMorePages = false
                break
            }
            
            // Process books from this page
            var newBooksThisPage = 0
            var duplicatesThisPage = 0
            
            for book in pageBooks {
                if !bookExistsInDatabase(book) {
                    // Add book to database as manga with finished status
                    let result = DatabaseManager.shared.saveBook(book, bookType: .manga, series: nil)
                    if result.success {
                        // Update to finished status since it was imported as read
                        if let savedBook = DatabaseManager.shared.getBook(byTitle: book.title, author: book.author) {
                            _ = DatabaseManager.shared.updateReadingStatus(bookId: savedBook.id!, status: .finished, customDate: Date())
                        }
                        newBooksThisPage += 1
                        print("DEBUG: Added book: \(book.title)")
                    } else {
                        print("DEBUG: Failed to save book \(book.title): \(result.error ?? "Unknown error")")
                    }
                } else {
                    duplicatesThisPage += 1
                    print("DEBUG: Skipped duplicate: \(book.title)")
                }
            }
            
            totalNewBooks += newBooksThisPage
            totalDuplicates += duplicatesThisPage
            allBooks.append(contentsOf: pageBooks)
            
            // Update progress
            let progress = ImportProgress(
                currentPage: currentPage,
                totalBooks: allBooks.count,
                newBooksAdded: totalNewBooks,
                duplicatesSkipped: totalDuplicates
            )
            
            await MainActor.run {
                progressCallback(progress)
            }
            
            currentPage += 1
            
            // Add a small delay to be respectful to the server
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
        
        print("DEBUG: Import completed. Total books: \(allBooks.count), New: \(totalNewBooks), Duplicates: \(totalDuplicates)")
        
        return ImportProgress(
            currentPage: currentPage - 1,
            totalBooks: allBooks.count,
            newBooksAdded: totalNewBooks,
            duplicatesSkipped: totalDuplicates
        )
    }
    
    private static func fetchUserReadBooksPage(userId: String, page: Int) async throws -> [Book] {
        let urlString = page == 1 
            ? "\(userBooksUrl)/\(userId)/books/read"
            : "\(userBooksUrl)/\(userId)/books/read?page=\(page)"
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        print("DEBUG: Fetching URL: \(urlString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        // Check for HTTP errors
        if let httpResponse = response as? HTTPURLResponse {
            guard 200...299 ~= httpResponse.statusCode else {
                print("DEBUG: HTTP Error: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
        }
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        
        return try parseUserReadBooksHtml(html)
    }
    
    private static func parseUserReadBooksHtml(_ html: String) throws -> [Book] {
        let document = try SwiftSoup.parse(html)
        
        // The structure might be different for user pages, let's try multiple selectors
        var bookElements: [Element] = []
        
        // Try the same selector first
        bookElements = try document.select("li.group__book").array()
        
        // If that doesn't work, try other common selectors for user book lists
        if bookElements.isEmpty {
            bookElements = try document.select("div.book").array()
        }
        
        if bookElements.isEmpty {
            bookElements = try document.select(".book-item").array()
        }
        
        print("DEBUG: Found \(bookElements.count) book elements on page")
        
        return try bookElements.compactMap { element -> Book? in
            // Try multiple parsing strategies
            if let book = try parseBookElementStrategy1(element) {
                return book
            }
            if let book = try parseBookElementStrategy2(element) {
                return book
            }
            return nil
        }
    }
    
    // Original parsing strategy
    private static func parseBookElementStrategy1(_ element: Element) throws -> Book? {
        let thumbnailImg = try element.select("div.book__thumbnail img").first()
        let thumbnail = try thumbnailImg?.attr("src") ?? ""
        let title = try thumbnailImg?.attr("alt") ?? ""
        
        guard !title.isEmpty else { return nil }
        
        let authorElement = try element.select("div.book__detail ul.detail__authors li").first()
        let author = try authorElement?.text().trimmingCharacters(in: .whitespacesAndNewlines)
        
        let pageElement = try element.select("div.book__detail div.detail__page").first()
        let pageText = try pageElement?.text().trimmingCharacters(in: .whitespacesAndNewlines)
        let pageCount = extractPageCount(from: pageText)
        
        return Book(title: title, thumbnailUrl: thumbnail, author: author, pageCount: pageCount)
    }
    
    // Alternative parsing strategy for user pages
    private static func parseBookElementStrategy2(_ element: Element) throws -> Book? {
        // Try alternative selectors that might be used on user pages
        let titleElement = try element.select(".book-title, .title, h3, h4").first()
        let title = try titleElement?.text().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        guard !title.isEmpty else { return nil }
        
        let thumbnailImg = try element.select("img").first()
        let thumbnail = try thumbnailImg?.attr("src") ?? ""
        
        let authorElement = try element.select(".author, .book-author").first()
        let author = try authorElement?.text().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return Book(title: title, thumbnailUrl: thumbnail, author: author, pageCount: nil)
    }
    
    private static func bookExistsInDatabase(_ book: Book) -> Bool {
        // Check if a book with the same title and author already exists
        return DatabaseManager.shared.bookExists(title: book.title, author: book.author)
    }
}
