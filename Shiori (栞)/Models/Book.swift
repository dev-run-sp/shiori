import Foundation

struct Book: Identifiable {
    let id = UUID()
    let title: String
    let thumbnailUrl: String
}
