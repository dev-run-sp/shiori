import Foundation

class OpenLibraryService {
    static let baseUrl = "https://openlibrary.org/search.json"
    
    static func searchBooks(query: String, page: Int = 1) async throws -> [Book] {
        let offset = (page - 1) * 20 // Open Library uses offset, not page numbers
        
        var urlComponents = URLComponents(string: baseUrl)!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "fields", value: "key,title,author_name,cover_i,first_publish_year,number_of_pages_median,edition_count"),
            URLQueryItem(name: "limit", value: "20"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        
        guard let url = urlComponents.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Shiori Book Library App - contact: support@shiori.app", forHTTPHeaderField: "User-Agent")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let searchResponse = try JSONDecoder().decode(OpenLibrarySearchResponse.self, from: data)
        return searchResponse.docs.compactMap { doc in
            convertToBook(doc)
        }
    }
    
    private static func convertToBook(_ doc: OpenLibraryDoc) -> Book? {
        // Ensure we have at least a title
        guard !doc.title.isEmpty else { return nil }
        
        let title = doc.title
        let author = doc.author_name?.first
        let pageCount = doc.number_of_pages_median
        
        // Create cover URL from cover_i if available
        let thumbnailUrl: String
        if let coverI = doc.cover_i {
            // Use Medium size (-M.jpg) for good quality thumbnails
            thumbnailUrl = "https://covers.openlibrary.org/b/id/\(coverI)-M.jpg"
            print("DEBUG: Generated cover URL: \(thumbnailUrl) for book: \(title)")
            
            // Also test with Small size as fallback option in logs
            let smallUrl = "https://covers.openlibrary.org/b/id/\(coverI)-S.jpg"
            print("DEBUG: Alternative Small URL: \(smallUrl)")
        } else {
            thumbnailUrl = ""
            print("DEBUG: No cover_i found for book: \(title)")
        }
        
        return Book(
            title: title,
            thumbnailUrl: thumbnailUrl,
            author: author,
            pageCount: pageCount
        )
    }
}

// MARK: - Response Models
struct OpenLibrarySearchResponse: Codable {
    let start: Int
    let num_found: Int
    let docs: [OpenLibraryDoc]
}

struct OpenLibraryDoc: Codable {
    let key: String
    let title: String
    let author_name: [String]?
    let cover_i: Int?
    let first_publish_year: Int?
    let number_of_pages_median: Int?
    let edition_count: Int?
}