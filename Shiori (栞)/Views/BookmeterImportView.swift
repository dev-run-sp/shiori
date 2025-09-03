import SwiftUI

struct BookmeterImportView: View {
    @State private var userId: String = ""
    @State private var isImporting: Bool = false
    @State private var importProgress: BookmeterService.ImportProgress?
    @State private var importCompleted: Bool = false
    @State private var errorMessage: String?
    @State private var showingAlert: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Import from Bookmeter")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Import your read manga from your Bookmeter profile")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 12) {
                        Text("How to find your User ID:")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            instructionStep(number: "1", text: "Go to your Bookmeter profile")
                            instructionStep(number: "2", text: "Look at the URL: bookmeter.com/users/[YOUR_ID]")
                            instructionStep(number: "3", text: "Copy the ID number and paste below")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // User ID Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Bookmeter User ID")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter your user ID", text: $userId)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .disabled(isImporting)
                        
                        Text("Example: 123456")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Import Progress
                    if let progress = importProgress {
                        VStack(spacing: 16) {
                            HStack {
                                Text("Import Progress")
                                    .font(.headline)
                                Spacer()
                            }
                            
                            VStack(spacing: 12) {
                                progressRow(title: "Current Page", value: "\(progress.currentPage)")
                                progressRow(title: "Total Books Found", value: "\(progress.totalBooks)")
                                progressRow(title: "New Books Added", value: "\(progress.newBooksAdded)")
                                progressRow(title: "Duplicates Skipped", value: "\(progress.duplicatesSkipped)")
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                    
                    // Import Button
                    Button(action: {
                        startImport()
                    }) {
                        HStack(spacing: 12) {
                            if isImporting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                            }
                            
                            Text(isImporting ? "Importing..." : "Start Import")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(canStartImport ? Color.blue : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!canStartImport || isImporting)
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Bookmeter Import")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                }
            )
            .alert("Import Result", isPresented: $showingAlert) {
                Button("OK") {
                    if importCompleted {
                        dismiss()
                    }
                }
            } message: {
                if let error = errorMessage {
                    Text("Import failed: \(error)")
                } else if let progress = importProgress, importCompleted {
                    Text("Import completed successfully!\n\n\(progress.newBooksAdded) new books added\n\(progress.duplicatesSkipped) duplicates skipped")
                } else {
                    Text("Import completed!")
                }
            }
        }
    }
    
    private var canStartImport: Bool {
        !userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func instructionStep(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private func progressRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
    
    private func startImport() {
        let trimmedUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedUserId.isEmpty else { return }
        
        isImporting = true
        importCompleted = false
        errorMessage = nil
        importProgress = nil
        
        Task {
            do {
                let finalProgress = try await BookmeterService.importUserReadBooks(userId: trimmedUserId) { progress in
                    self.importProgress = progress
                }
                
                await MainActor.run {
                    self.importProgress = finalProgress
                    self.isImporting = false
                    self.importCompleted = true
                    self.showingAlert = true
                    
                    // Notify other views to refresh
                    NotificationCenter.default.post(name: .bookUpdated, object: nil)
                }
                
            } catch {
                await MainActor.run {
                    self.isImporting = false
                    self.errorMessage = error.localizedDescription
                    self.showingAlert = true
                }
            }
        }
    }
}

#Preview {
    BookmeterImportView()
}