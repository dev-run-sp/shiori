import SwiftUI

struct BookPreviewView: View {
    let book: Book
    
    var body: some View {
        AsyncImage(url: URL(string: book.thumbnailUrl)) { image in
            image
                .cornerRadius(12)
                .shadow(radius: 8)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 200, height: 300)
                .cornerRadius(12)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.6))
                        Text("No Cover")
                            .font(.headline)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                )
                .shadow(radius: 8)
        }
    }
}

struct SeriesPreviewView: View {
    let series: SeriesData
    
    var body: some View {
        AsyncImage(url: URL(string: series.lastBookThumbnail.isEmpty ? "" : series.lastBookThumbnail)) { image in
            image
                .cornerRadius(12)
                .shadow(radius: 8)
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 200, height: 300)
                .cornerRadius(12)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "books.vertical")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.8))
                        Text("No Cover")
                            .font(.headline)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                )
                .shadow(radius: 8)
        }
    }
}

