import Foundation

struct Book: Identifiable {
    let id = UUID()
    let title: String
    let thumbnailUrl: String
    let author: String?
    let pageCount: Int?
}
