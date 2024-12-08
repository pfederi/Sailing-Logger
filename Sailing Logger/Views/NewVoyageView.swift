import SwiftUI
import UIKit

struct KeyboardToolbar: UIViewRepresentable {
    let previousAction: () -> Void
    let nextAction: () -> Void
    let isPreviousDisabled: Bool
    let isNextDisabled: Bool
    
    func makeUIView(context: Context) -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        
        let previousButton = UIBarButtonItem(image: UIImage(systemName: "chevron.up"),
                                           style: .plain,
                                           target: context.coordinator,
                                           action: #selector(Coordinator.previousTapped))
        previousButton.isEnabled = !isPreviousDisabled
        
        let nextButton = UIBarButtonItem(image: UIImage(systemName: "chevron.down"),
                                       style: .plain,
                                       target: context.coordinator,
                                       action: #selector(Coordinator.nextTapped))
        nextButton.isEnabled = !isNextDisabled
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: context.coordinator, action: #selector(Coordinator.doneTapped))
        
        toolbar.setItems([previousButton, nextButton, flexSpace, doneButton], animated: false)
        return toolbar
    }
    
    func updateUIView(_ uiView: UIToolbar, context: Context) {
        if let items = uiView.items {
            items[0].isEnabled = !isPreviousDisabled
            items[1].isEnabled = !isNextDisabled
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(previousAction: previousAction, nextAction: nextAction)
    }
    
    class Coordinator: NSObject {
        let previousAction: () -> Void
        let nextAction: () -> Void
        
        init(previousAction: @escaping () -> Void, nextAction: @escaping () -> Void) {
            self.previousAction = previousAction
            self.nextAction = nextAction
            super.init()
        }
        
        @objc func previousTapped() {
            previousAction()
        }
        
        @objc func nextTapped() {
            nextAction()
        }
        
        @objc func doneTapped() {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), 
                                         to: nil, 
                                         from: nil, 
                                         for: nil)
        }
    }
}

struct CustomButtonStyle: ButtonStyle {
    var isEnabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(configuration.isPressed ? MaritimeColors.navy.opacity(0.8) : (isEnabled ? MaritimeColors.navy : Color.gray))
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}

struct NewVoyageView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var voyageStore: VoyageStore
    @ObservedObject var logStore: LogStore
    
    @State private var voyageName = ""
    @State private var startDate = Date()
    @State private var boatType = ""
    @State private var boatName = ""
    @State private var crew: [CrewMember] = []
    @State private var showingAddCrew = false
    @State private var newCrewName = ""
    @State private var newCrewRole = CrewRole.crew
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var crewToEditIndex: Int?
    @FocusState private var focusedField: Field?
    @State private var showingFilePicker = false
    @State private var showingImportSuccessAlert = false
    @State private var importSuccessMessage = ""
    
    private enum Field: Int {
        case voyageName, boatType, boatName
    }
    
    private var hasSkipper: Bool {
        crew.contains { $0.role == .skipper }
    }
    
    private var formIsValid: Bool {
        !voyageName.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voyage Details")) {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(MaritimeColors.navy)
                        TextField("Voyage Name", text: $voyageName)
                            .focused($focusedField, equals: .voyageName)
                    }
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(MaritimeColors.navy)
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    }
                }
                
                Section(header: Text("Boat Details")) {
                    HStack {
                        Image(systemName: "sailboat")
                            .foregroundColor(MaritimeColors.navy)
                        TextField("Boat Type", text: $boatType)
                            .focused($focusedField, equals: .boatType)
                    }
                    HStack {
                        Image(systemName: "pencil.and.scribble")
                            .foregroundColor(MaritimeColors.navy)
                        TextField("Boat Name", text: $boatName)
                            .focused($focusedField, equals: .boatName)
                    }
                }
                
                CrewSection(
                    crew: $crew,
                    showingAddCrew: $showingAddCrew,
                    crewToEditIndex: $crewToEditIndex,
                    hasSkipper: hasSkipper
                )
                
                Section {
                    Button("Create Voyage") {
                        createVoyage()
                    }
                    .buttonStyle(CustomButtonStyle(isEnabled: formIsValid))
                    .disabled(!formIsValid)
                    .padding(.horizontal, -20)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                
                Section {
                    Button(action: {
                        showingFilePicker = true
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "square.and.arrow.down")
                            Text("Import Voyage Data")
                            Spacer()
                        }
                    }
                    .foregroundColor(MaritimeColors.navy)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.white)
                    .padding(.horizontal, -20)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
            .navigationTitle("New Voyage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    KeyboardToolbar(
                        previousAction: { moveToPreviousField() },
                        nextAction: { moveToNextField() },
                        isPreviousDisabled: focusedField == .voyageName,
                        isNextDisabled: focusedField == .boatName
                    )
                }
            }
            .sheet(isPresented: $showingAddCrew) {
                AddCrewSheet(
                    crew: $crew,
                    isPresented: $showingAddCrew,
                    crewToEditIndex: $crewToEditIndex,
                    existingSkipper: hasSkipper,
                    onSave: {
                        // In NewVoyageView müssen wir nichts speichern,
                        // da die Crew erst beim Erstellen der Voyage gespeichert wird
                    }
                )
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPicker { data in
                    handleImportedData(data)
                }
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
            .alert("Import Successful", isPresented: $showingImportSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importSuccessMessage)
            }
        }
    }
    
    private func deleteCrew(at offsets: IndexSet) {
        crew.remove(atOffsets: offsets)
    }
    
    private func createVoyage() {
        if voyageStore.hasActiveVoyage {
            showAlert = true
            alertMessage = "Please end the current voyage before starting a new one"
            return
        }
        
        let newVoyage = Voyage(
            name: voyageName,
            startDate: startDate,
            crew: crew,
            boatType: boatType,
            boatName: boatName
        )
        
        voyageStore.addVoyage(newVoyage)
        dismiss()
    }
    
    private func moveToNextField() {
        guard let currentField = focusedField else { return }
        focusedField = Field(rawValue: currentField.rawValue + 1)
    }
    
    private func moveToPreviousField() {
        guard let currentField = focusedField else { return }
        focusedField = Field(rawValue: currentField.rawValue - 1)
    }
    
    private func handleImportedData(_ data: Data) {
        do {
            print("Starting to decode imported data...")
            let decoder = JSONDecoder()
            let importedVoyage = try decoder.decode(Voyage.self, from: data)
            
            // Aktualisiere die Formularfelder mit den importierten Daten
            voyageName = importedVoyage.name
            startDate = importedVoyage.startDate
            boatType = importedVoyage.boatType
            boatName = importedVoyage.boatName
            crew = importedVoyage.crew
            
            // Füge zuerst die Voyage hinzu
            voyageStore.addVoyage(importedVoyage)
            
            // Dann importiere die LogEntries
            if !importedVoyage.logEntries.isEmpty {
                logStore.importEntries(importedVoyage.logEntries)
                logStore.reloadEntries()
            }
            
            importSuccessMessage = "Successfully imported voyage with \(importedVoyage.logEntries.count) log entries."
            showingImportSuccessAlert = true
            
            print("✅ Import successful with \(importedVoyage.logEntries.count) entries")
            
            // Optional: Automatisch schließen nach erfolgreichem Import
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                dismiss()
            }
            
        } catch {
            print("❌ Error decoding voyage data: \(error)")
            alertMessage = "Error importing data: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

struct AddCrewSheet: View {
    @Binding var crew: [CrewMember]
    @Binding var isPresented: Bool
    @Binding var crewToEditIndex: Int?
    let existingSkipper: Bool
    let onSave: () -> Void
    
    @State private var name: String
    @State private var role: CrewRole
    
    init(crew: Binding<[CrewMember]>, 
         isPresented: Binding<Bool>, 
         crewToEditIndex: Binding<Int?>, 
         existingSkipper: Bool,
         onSave: @escaping () -> Void) {
        self._crew = crew
        self._isPresented = isPresented
        self._crewToEditIndex = crewToEditIndex
        self.existingSkipper = existingSkipper
        self.onSave = onSave
        
        // Initialisiere mit existierenden Werten wenn im Edit-Modus
        if let editIndex = crewToEditIndex.wrappedValue,
           editIndex < crew.wrappedValue.count {
            let member = crew.wrappedValue[editIndex]
            self._name = State(initialValue: member.name)
            self._role = State(initialValue: member.role)
        } else {
            self._name = State(initialValue: "")
            self._role = State(initialValue: existingSkipper ? .crew : .skipper)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Name", text: $name)
                
                Picker("Role", selection: $role) {
                    Text(CrewRole.skipper.rawValue).tag(CrewRole.skipper)
                        .disabled(existingSkipper)
                    Text(CrewRole.secondSkipper.rawValue).tag(CrewRole.secondSkipper)
                        .disabled(crew.contains { $0.role == .secondSkipper })
                    Text(CrewRole.crew.rawValue).tag(CrewRole.crew)
                }
            }
            .navigationTitle(crewToEditIndex != nil ? "Edit Crew Member" : "Add Crew Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(crewToEditIndex != nil ? "Save" : "Add") {
                        let crewMember = CrewMember(name: name, role: role)
                        if let editIndex = crewToEditIndex {
                            crew[editIndex] = crewMember
                        } else {
                            crew.append(crewMember)
                        }
                        onSave()
                        isPresented = false
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        NewVoyageView(voyageStore: VoyageStore(), logStore: LogStore(voyageStore: VoyageStore()))
    }
} 