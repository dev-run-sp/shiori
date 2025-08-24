import SwiftUI

struct BookDetailView: View {
    let book: Book
    let searchResults: [Book]
    @Environment(\.dismiss) private var dismiss
    @State private var showingSeriesOptions = false
    @State private var readingStatus: ReadingStatus = .wantToRead
    
    // No drag states needed for immediate dismiss
    
    enum ReadingStatus: String, CaseIterable {
        case wantToRead = "Add to Reading"
        case currentlyReading = "Currently Reading"
        case finished = "Read"
        
        var color: Color {
            switch self {
            case .wantToRead: return .blue
            case .currentlyReading: return .orange
            case .finished: return .green
            }
        }
        
        var icon: String {
            switch self {
            case .wantToRead: return "book"
            case .currentlyReading: return "book.fill"
            case .finished: return "checkmark.circle.fill"
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Background view (actual search results)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(searchResults.indices, id: \.self) { index in
                        let searchBook = searchResults[index]
                        HStack(spacing: 20) {
                            AsyncImage(url: URL(string: searchBook.thumbnailUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 100, height: 140)
                                    .cornerRadius(8)
                                    .shadow(radius: 2)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 100, height: 140)
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(searchBook.title)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                if let author = searchBook.author {
                                    Text("Author: \(author)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                if let pageCount = searchBook.pageCount {
                                    Text("Pages: \(pageCount)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        Divider()
                    }
                }
            }
            .opacity(0.7)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.customBackground)
            
            // Main content
            ScrollView {
                VStack(spacing: 20) {
                
                // Book thumbnail
                AsyncImage(url: URL(string: book.thumbnailUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 300, maxHeight: 420)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 300, height: 420)
                        .cornerRadius(16)
                        .overlay(
                            Image(systemName: "book.closed")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                        )
                }
                
                // Book details
                VStack(spacing: 16) {
                    // Title
                    Text(book.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                    
                    // Author
                    if let author = book.author {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.secondary)
                            Text(author)
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Page count
                    if let pageCount = book.pageCount {
                        HStack {
                            Image(systemName: "doc.text")
                                .foregroundColor(.secondary)
                            Text("\(pageCount) pages")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.horizontal)
                
                // Action buttons
                VStack(spacing: 16) {
                    // Reading status button
                    Button(action: {
                        cycleReadingStatus()
                    }) {
                        HStack {
                            Image(systemName: readingStatus.icon)
                            Text(readingStatus.rawValue)
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(readingStatus.color)
                        .cornerRadius(12)
                    }
                    
                    // Series button
                    Button(action: {
                        showingSeriesOptions = true
                    }) {
                        HStack {
                            Image(systemName: "books.vertical")
                            Text("Add to Series")
                        }
                        .font(.headline)
                        .foregroundColor(.blue)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    }
                }
                .padding(.horizontal)
                
                    Spacer(minLength: 50)
                }
            }
            .background(Color.customBackground)
        }
        .navigationBarHidden(true)
        .highPriorityGesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    let translation = value.translation.height
                    if translation > 30 {
                        // Immediate dismiss as soon as threshold is met
                        withAnimation(.easeOut(duration: 0.3)) {
                            dismiss()
                        }
                    }
                }
        )
        .sheet(isPresented: $showingSeriesOptions) {
            SeriesSelectionView()
        }
    }
    
    private func cycleReadingStatus() {
        let allCases = ReadingStatus.allCases
        if let currentIndex = allCases.firstIndex(of: readingStatus) {
            let nextIndex = (currentIndex + 1) % allCases.count
            readingStatus = allCases[nextIndex]
        }
    }
}

struct SeriesSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingCreateSeries = false
    @State private var newSeriesName = ""
    
    // Mock series data - you can replace with actual data later
    let existingSeries = ["Naruto Series", "One Piece Collection", "Studio Ghibli"]
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section("Existing Series") {
                        ForEach(existingSeries, id: \.self) { series in
                            Button(action: {
                                // Add to existing series
                                dismiss()
                            }) {
                                HStack {
                                    Text(series)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                // Create new series button
                Button(action: {
                    showingCreateSeries = true
                }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create New Series")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Add to Series")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Cancel") {
                    dismiss()
                }
            )
        }
        .alert("Create New Series", isPresented: $showingCreateSeries) {
            TextField("Series Name", text: $newSeriesName)
            Button("Create") {
                // Create new series logic
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        }
    }
}

#Preview {
    BookDetailView(
        book: Book(
            title: "Sample Book Title That Might Be Long",
            thumbnailUrl: "https://example.com/book.jpg",
            author: "Sample Author",
            pageCount: 288
        ),
        searchResults: [
            Book(title: "Book 1", thumbnailUrl: "", author: "Author 1", pageCount: 200),
            Book(title: "Book 2", thumbnailUrl: "", author: "Author 2", pageCount: 300)
        ]
    )
}