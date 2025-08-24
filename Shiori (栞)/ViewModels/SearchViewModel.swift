import Foundation
import SwiftSoup

@MainActor
class SearchViewModel: ObservableObject {
    @Published var books: [Book] = []
    @Published var isLoading = false
    @Published var error: String?
    
    func searchBookmeter(query: String) async {
        isLoading = true
        error = nil
        
        do {
            let url = "https://bookmeter.com/search?keyword=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
            let (data, _) = try await URLSession.shared.data(from: URL(string: url)!)
            
            if let html = String(data: data, encoding: .utf8) {
                let document = try SwiftSoup.parse(html)
                let bookElements = try document.select(".book-detail__title") // We'll need to verify this selector
                
                books = try bookElements.map { element in
                    let title = try element.text()
                    let thumbnailUrl = try element.parent()?.select("img").first()?.attr("src") ?? ""
                    return Book(title: title, thumbnailUrl: thumbnailUrl)
                }
            }
        } catch {
            self.error = error.localizedDescription
        }
        
        isLoading = false
    }
}
