import SwiftUI

struct TestSearchView: View {
    
    func searchBooks(reset: Bool) async {
        if reset {
            currentPage = 1
            results = []
            hasMorePages = true
        }
        
        guard !isLoading && hasMorePages else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let newResults = try await BookmeterService.searchBooks(query: "naruto", page: currentPage)
            if newResults.isEmpty {
                hasMorePages = false
            } else {
                results.append(contentsOf: newResults)
                currentPage += 1
            }
        } catch {
            errorMessage = error.localizedDescription
            print("Error: \(error)")
        }
        
        isLoading = false
    }
    
    @State private var results: [Book] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var currentPage = 1
    @State private var hasMorePages = true
    
    var body: some View {
        VStack(spacing: 20) {
            Button("Test Search 'Naruto'") {
                Task {
                    await searchBooks(reset: true)
                }
            }
            .buttonStyle(.borderedProminent)
            
            // Removed loading indicator since it's now in the scroll view
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
            }
            
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(results) { book in
                        HStack(spacing: 15) {
                            AsyncImage(url: URL(string: book.thumbnailUrl)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 60, height: 80)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 60, height: 80)
                            }
                            
                            Text(book.title)
                                .font(.headline)
                        }
                        .padding(.horizontal)
                        Divider()
                        .onAppear {
                            // If this is one of the last items, load more
                            if book.id == results.last?.id && !isLoading && hasMorePages {
                                Task {
                                    await searchBooks(reset: false)
                                }
                            }
                        }
                    }
                    
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(1.5)
                                .frame(width: 50, height: 50)
                                .background(Color.white.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .shadow(radius: 2)
                            Spacer()
                        }
                        .padding(.vertical, 20)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    TestSearchView()
}
