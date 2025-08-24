import Foundation
import SwiftSoup

class BookmeterService {
    static let baseUrl = "https://bookmeter.com/search"
    
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
            let thumbnail = try element.select("div.book__thumbnail img").first()?.attr("src") ?? ""
            let title = try element.select("div.book__detail div.detail__title a").first()?.text() ?? ""
            
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
}
