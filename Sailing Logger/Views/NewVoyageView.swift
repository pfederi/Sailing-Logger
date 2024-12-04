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
            .background(configuration.isPressed ? Color.blue.opacity(0.8) : (isEnabled ? Color.blue : Color.gray))
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}

struct NewVoyageView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var voyageStore: VoyageStore
    
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
    @FocusState private var focusedField: Field?
    
    private enum Field: Int {
        case voyageName, boatType, boatName
    }
    
    private var hasSkipper: Bool {
        crew.contains { $0.role == .skipper }
    }
    
    private var formIsValid: Bool {
        !voyageName.isEmpty && 
        !boatType.isEmpty && 
        !boatName.isEmpty && 
        hasSkipper &&
        !crew.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voyage Details")) {
                    TextField("Voyage Name", text: $voyageName)
                        .focused($focusedField, equals: .voyageName)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                KeyboardToolbar(
                                    previousAction: { moveToPreviousField() },
                                    nextAction: { moveToNextField() },
                                    isPreviousDisabled: focusedField == .voyageName,
                                    isNextDisabled: focusedField == .boatName
                                )
                            }
                        }
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                }
                
                Section(header: Text("Boat Details")) {
                    TextField("Boat Type", text: $boatType)
                        .focused($focusedField, equals: .boatType)
                    TextField("Boat Name", text: $boatName)
                        .focused($focusedField, equals: .boatName)
                }
                
                Section(header: Text("Crew")) {
                    ForEach(crew) { member in
                        HStack {
                            Text(member.name)
                            Spacer()
                            Text(member.role.rawValue)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deleteCrew)
                    
                    Button(action: { showingAddCrew = true }) {
                        Label("Add Crew Member", systemImage: "person.badge.plus")
                    }
                }
                
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
            }
            .navigationTitle("New Voyage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddCrew) {
                AddCrewSheet(
                    crew: $crew,
                    isPresented: $showingAddCrew,
                    existingSkipper: hasSkipper
                )
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
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
}

struct AddCrewSheet: View {
    @Binding var crew: [CrewMember]
    @Binding var isPresented: Bool
    let existingSkipper: Bool
    
    @State private var name = ""
    @State private var role: CrewRole
    
    init(crew: Binding<[CrewMember]>, isPresented: Binding<Bool>, existingSkipper: Bool) {
        self._crew = crew
        self._isPresented = isPresented
        self.existingSkipper = existingSkipper
        self._role = State(initialValue: existingSkipper ? .crew : .skipper)
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
                
                Button("Add") {
                    let crewMember = CrewMember(name: name, role: role)
                    crew.append(crewMember)
                    isPresented = false
                }
                .disabled(name.isEmpty)
            }
            .navigationTitle("Add Crew Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        NewVoyageView(voyageStore: VoyageStore())
    }
} 