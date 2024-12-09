import SwiftUI
import UniformTypeIdentifiers

struct DocumentPicker: UIViewControllerRepresentable {
    let onImport: (Data) -> Void
    @Environment(\.colorScheme) var colorScheme
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.json])
        picker.delegate = context.coordinator
        
        // Apply themed colors
        picker.view.tintColor = MaritimeColors.navyUI
        
        // Customize the appearance of the navigation bar globally
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(MaritimeColors.background(for: colorScheme))
        appearance.titleTextAttributes = [.foregroundColor: UIColor(MaritimeColors.navy(for: colorScheme))]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(MaritimeColors.navy(for: colorScheme))]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // Update colors if needed when theme changes
        uiViewController.view.tintColor = MaritimeColors.navyUI
    }
    
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