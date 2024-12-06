import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    let onImport: (Data) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onImport: onImport)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onImport: (Data) -> Void
        
        init(onImport: @escaping (Data) -> Void) {
            self.onImport = onImport
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Failed to access file")
                return
            }
            
            defer { url.stopAccessingSecurityScopedResource() }
            
            do {
                let data = try Data(contentsOf: url)
                onImport(data)
            } catch {
                print("❌ Error reading file: \(error)")
            }
        }
    }
} 