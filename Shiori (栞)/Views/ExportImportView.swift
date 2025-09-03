import SwiftUI
import UniformTypeIdentifiers

struct ExportImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showingExportShare = false
    @State private var showingImportPicker = false
    @State private var exportedFileURL: URL?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var importResult: DatabaseManager.ImportResult?
    @State private var replaceExisting = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Export & Import Library")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Export your library to JSON for external editing, then import it back")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Export Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Export Data")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Export to JSON")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Creates a structured JSON file with all your books, series, and reading progress")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            
                            Button(action: {
                                exportLibraryData()
                            }) {
                                HStack(spacing: 8) {
                                    if isExporting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "square.and.arrow.up")
                                    }
                                    Text(isExporting ? "Exporting..." : "Export Library")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                            .disabled(isExporting)
                        }
                        .padding(16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Divider()
                    
                    // Import Section
                    VStack(spacing: 16) {
                        HStack {
                            Text("Import Data")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Import from JSON")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("Import books from a JSON file. Choose to merge with existing data or replace it entirely")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                            }
                            
                            Toggle("Replace existing library", isOn: $replaceExisting)
                                .font(.subheadline)
                            
                            if replaceExisting {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundColor(.orange)
                                    Text("This will delete all existing books and replace them with imported data")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Spacer()
                                }
                            }
                            
                            Button(action: {
                                showingImportPicker = true
                            }) {
                                HStack(spacing: 8) {
                                    if isImporting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                    }
                                    Text(isImporting ? "Importing..." : "Import Library")
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(replaceExisting ? Color.orange : Color.green)
                                .cornerRadius(10)
                            }
                            .disabled(isImporting)
                        }
                        .padding(16)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // JSON Format Info
                    VStack(spacing: 12) {
                        HStack {
                            Text("JSON Structure")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("The exported JSON contains:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                bulletPoint("Export metadata (date, app version)")
                                bulletPoint("All books with complete information")
                                bulletPoint("Series assignments")
                                bulletPoint("Reading status and progress dates")
                                bulletPoint("Book types (English, Japanese, Manga)")
                            }
                            .padding(.leading, 8)
                        }
                        .padding(16)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Export & Import")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
        .sheet(isPresented: $showingExportShare) {
            if let url = exportedFileURL {
                ActivityView(activityItems: [url])
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [UTType.json],
            allowsMultipleSelection: false
        ) { result in
            handleImportFile(result)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") { }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func exportLibraryData() {
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let result = DatabaseManager.shared.exportLibraryData()
            
            DispatchQueue.main.async {
                isExporting = false
                
                switch result {
                case .success(let jsonString):
                    // Create a temporary file URL
                    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                    let dateString = dateFormatter.string(from: Date())
                    let fileName = "shiori_library_export_\(dateString).json"
                    let fileURL = documentsPath.appendingPathComponent(fileName)
                    
                    do {
                        try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
                        exportedFileURL = fileURL
                        showingExportShare = true
                    } catch {
                        alertTitle = "Export Failed"
                        alertMessage = "Could not create export file: \(error.localizedDescription)"
                        showingAlert = true
                    }
                case .failure(let error):
                    alertTitle = "Export Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func handleImportFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            importFromFile(url)
        case .failure(let error):
            alertTitle = "Import Failed"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
    
    private func importFromFile(_ url: URL) {
        isImporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Need to start accessing the security-scoped resource
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                
                print("DEBUG: Attempting to read file at: \(url)")
                let jsonString = try String(contentsOf: url, encoding: .utf8)
                print("DEBUG: Successfully read JSON string, length: \(jsonString.count)")
                
                let result = DatabaseManager.shared.importLibraryData(jsonString, replaceExisting: replaceExisting)
                
                DispatchQueue.main.async {
                    isImporting = false
                    
                    switch result {
                    case .success(let importResult):
                        self.importResult = importResult
                        if importResult.isSuccessful {
                            alertTitle = "Import Successful"
                            alertMessage = "Import completed: \(importResult.summary)"
                            NotificationCenter.default.post(name: .bookUpdated, object: nil)
                        } else {
                            alertTitle = "Import Issues"
                            alertMessage = "Import had issues: \(importResult.summary)\n\nFirst few errors:\n" + importResult.errors.prefix(3).joined(separator: "\n")
                        }
                        showingAlert = true
                    case .failure(let error):
                        alertTitle = "Import Failed"
                        alertMessage = "Import error: \(error.localizedDescription)"
                        showingAlert = true
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    isImporting = false
                    alertTitle = "Import Failed"
                    alertMessage = "Could not read file: \(error.localizedDescription)\n\nFile: \(url.lastPathComponent)"
                    showingAlert = true
                }
            }
        }
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    ExportImportView()
}