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
            
            return Book(title: title, thumbnailUrl: thumbnail)
        }
    }
}
