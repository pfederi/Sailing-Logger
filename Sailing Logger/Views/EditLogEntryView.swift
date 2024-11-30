import SwiftUI

struct EditLogEntryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var logStore: LogStore
    let entry: LogEntry
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    
    @State private var timestamp: Date
    @State private var coordinates: Coordinates
    @State private var magneticCourse: Double?
    @State private var courseOverGround: Double?
    @State private var distance: Double?
    @State private var barometer: Double?
    @State private var temperature: Double?
    @State private var visibility: Int?
    @State private var cloudCover: Int?
    @State private var windDirection: Compass
    @State private var windSpeed: Double?
    @State private var windSpeedBft: Int
    @State private var sailState: SailState
    @State private var speed: Double?
    @State private var engineState: EngineState
    @State private var selectedManeuver: Maneuver?
    @State private var notes: String
    @State private var magneticCourseError: String?
    @State private var cogError: String?
    @State private var sails = Sails()
    @FocusState private var focusedField: Field?
    @State private var latitudeDegrees: Double
    @State private var latitudeMinutes: Double
    @State private var longitudeDegrees: Double
    @State private var longitudeMinutes: Double
    @State private var latitudeDirection: Bool  // true = N, false = S
    @State private var longitudeDirection: Bool  // true = E, false = W
    @State private var coordinatesError: String?
    @State private var maxDate = Date()
    
    private enum Field: Hashable, CaseIterable {
        case latitudeDegrees
        case latitudeMinutes
        case longitudeDegrees
        case longitudeMinutes
        case distance
        case magneticCourse
        case courseOverGround
        case speed
        case barometer
        case temperature
        case windSpeed
        case notes
    }
    
    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter
    }()
    
    private let degreesFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    
    private let minutesFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2  // Immer 2 Dezimalstellen anzeigen
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    init(logStore: LogStore, entry: LogEntry, locationManager: LocationManager, tileManager: OpenSeaMapTileManager) {
        self.logStore = logStore
        self.entry = entry
        self.locationManager = locationManager
        self.tileManager = tileManager
        
        _timestamp = State(initialValue: entry.timestamp)
        _coordinates = State(initialValue: entry.coordinates)
        _distance = State(initialValue: entry.distance == 0 ? nil : entry.distance)
        _magneticCourse = State(initialValue: entry.magneticCourse == 0 ? nil : entry.magneticCourse)
        _courseOverGround = State(initialValue: entry.courseOverGround == 0 ? nil : entry.courseOverGround)
        _barometer = State(initialValue: entry.barometer == 1013.25 ? nil : entry.barometer)
        _temperature = State(initialValue: entry.temperature == 0 ? nil : entry.temperature)
        _visibility = State(initialValue: entry.visibility == 0 ? nil : entry.visibility)
        _cloudCover = State(initialValue: entry.cloudCover == 0 ? nil : entry.cloudCover)
        _windDirection = State(initialValue: entry.wind.direction)
        _windSpeed = State(initialValue: entry.wind.speedKnots == 0 ? nil : entry.wind.speedKnots)
        _windSpeedBft = State(initialValue: entry.wind.beaufortForce)
        _sailState = State(initialValue: entry.sailState)
        _speed = State(initialValue: entry.speed)
        _engineState = State(initialValue: entry.engineState)
        _selectedManeuver = State(initialValue: entry.maneuver)
        _notes = State(initialValue: entry.notes ?? "")
        _sails = State(initialValue: entry.sails)
        print("Loading sails in EditView: \(entry.sails)")
        
        let (latDeg, latMin) = abs(entry.coordinates.latitude).splitToDegreesAndMinutes()
        let (lonDeg, lonMin) = abs(entry.coordinates.longitude).splitToDegreesAndMinutes()
        
        _latitudeDegrees = State(initialValue: latDeg)
        _latitudeMinutes = State(initialValue: latMin)
        _longitudeDegrees = State(initialValue: lonDeg)
        _longitudeMinutes = State(initialValue: lonMin)
        _latitudeDirection = State(initialValue: entry.coordinates.latitude >= 0)
        _longitudeDirection = State(initialValue: entry.coordinates.longitude >= 0)
    }
    
    private func validateCourse(_ value: Double?) -> Bool {
        guard let value = value else { return true }
        return value >= 0 && value <= 360
    }
    
    private func courseBinding(for courseValue: Binding<Double?>, error: Binding<String?>) -> Binding<Double?> {
        Binding(
            get: { courseValue.wrappedValue },
            set: { newValue in
                if let value = newValue {
                    if value >= 0 && value <= 360 {
                        courseValue.wrappedValue = value
                        error.wrappedValue = nil
                    } else {
                        error.wrappedValue = "Course must be between 0° and 360°"
                    }
                } else {
                    courseValue.wrappedValue = newValue
                    error.wrappedValue = nil
                }
            }
        )
    }
    
    private func windSpeedToBeaufort(_ speed: Double) -> Int {
        switch speed {
        case 0...1: return 0      // < 1 knot
        case 1...3: return 1      // 1-3 knots
        case 4...6: return 2      // 4-6 knots
        case 7...10: return 3     // 7-10 knots
        case 11...16: return 4    // 11-16 knots
        case 17...21: return 5    // 17-21 knots
        case 22...27: return 6    // 22-27 knots
        case 28...33: return 7    // 28-33 knots
        case 34...40: return 8    // 34-40 knots
        case 41...47: return 9    // 41-47 knots
        case 48...55: return 10   // 48-55 knots
        case 56...63: return 11   // 56-63 knots
        default: return 12        // >= 64 knots
        }
    }

    private func beaufortToWindSpeed(_ bft: Int) -> Double {
        switch bft {
        case 0: return 0      // Calm
        case 1: return 2      // Light air
        case 2: return 5      // Light breeze
        case 3: return 8.5    // Gentle breeze
        case 4: return 13.5   // Moderate breeze
        case 5: return 19     // Fresh breeze
        case 6: return 24.5   // Strong breeze
        case 7: return 30.5   // Near gale
        case 8: return 37     // Gale
        case 9: return 44     // Strong gale
        case 10: return 51.5  // Storm
        case 11: return 59.5  // Violent storm
        case 12: return 64    // Hurricane
        default: return 0
        }
    }
    
    private var canMovePrevious: Bool {
        guard let currentField = focusedField,
              let currentIndex = Field.allCases.firstIndex(of: currentField)
        else { return false }
        return currentIndex > 0
    }
    
    private var canMoveNext: Bool {
        guard let currentField = focusedField,
              let currentIndex = Field.allCases.firstIndex(of: currentField)
        else { return false }
        return currentIndex < Field.allCases.count - 1
    }
    
    private func moveToNextField() {
        guard let currentField = focusedField,
              let currentIndex = Field.allCases.firstIndex(of: currentField),
              currentIndex < Field.allCases.count - 1
        else { return }
        focusedField = Field.allCases[currentIndex + 1]
    }
    
    private func moveToPreviousField() {
        guard let currentField = focusedField,
              let currentIndex = Field.allCases.firstIndex(of: currentField),
              currentIndex > 0
        else { return }
        focusedField = Field.allCases[currentIndex - 1]
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            Form {
                timeAndPositionSection
                    .listSectionSpacing(.compact)
                
                mapSection
                
                Section {
                    HStack {
                        Image(systemName: "arrow.triangle.swap")
                            .frame(width: 24)
                            .foregroundColor(.blue)
                        Text("Distance")
                        Spacer()
                        TextField("", value: $distance, formatter: numberFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .distance)
                            .id(Field.distance)
                        Text("nm")
                    }
                }
                .listSectionSpacing(.compact)
                
                Section("Maneuvers") {
                    HStack {
                        Image(systemName: "helm")
                            .frame(width: 24)
                            .foregroundColor(.blue)
                        Text("Maneuver")
                        Spacer()
                        Picker("", selection: $selectedManeuver) {
                            Text("Select Maneuver").tag(nil as Maneuver?)
                            ForEach(Maneuver.Category.allCases, id: \.self) { category in
                                Section(header: Text(category.rawValue)) {
                                    ForEach(Maneuver.allCases.filter { $0.category == category }, id: \.self) { maneuver in
                                        Text(maneuver.rawValue)
                                            .tag(maneuver as Maneuver?)
                                    }
                                }
                            }
                        }
                        .tint(.black)
                    }
                }
                
                Section("Conditions") {
                    HStack {
                        Image(systemName: "safari")
                            .frame(width: 24)
                            .foregroundColor(.blue)
                        Text("C°")
                        Spacer()
                        TextField("", value: courseBinding(for: $magneticCourse, error: $magneticCourseError), formatter: numberFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .magneticCourse)
                            .id(Field.magneticCourse)
                        Text("°")
                    }
                    if let error = magneticCourseError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "safari.fill")
                            .frame(width: 24)
                            .foregroundColor(.blue)
                        Text("COG")
                        Spacer()
                        TextField("", value: courseBinding(for: $courseOverGround, error: $cogError), formatter: numberFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .courseOverGround)
                            .id(Field.courseOverGround)
                        Text("°")
                    }
                    if let error = cogError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: "speedometer")
                            .frame(width: 24)
                            .foregroundColor(.blue)
                        Text("SOG")
                        Spacer()
                        TextField("", value: $speed, formatter: numberFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .speed)
                            .id(Field.speed)
                        Text("kts")
                    }
                    
                    HStack {
                        Image(systemName: "barometer")
                            .frame(width: 24)
                            .foregroundColor(.blue)
                        Text("Barometer")
                        Spacer()
                        TextField("", value: $barometer, formatter: numberFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .barometer)
                            .id(Field.barometer)
                        Text("hPa")
                    }

                    HStack {
                        Image(systemName: "thermometer")
                            .frame(width: 24)
                            .foregroundColor(.blue)
                        Text("Temperature")
                        Spacer()
                        TextField("", value: $temperature, formatter: numberFormatter)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .focused($focusedField, equals: .temperature)
                            .id(Field.temperature)
                        Text("°C")
                    }
                    
                    HStack {
                        Image(systemName: "eye")
                            .frame(width: 24)
                            .foregroundColor(.blue)
                        Text("Visibility")
                        Spacer()
                        Picker("", selection: $visibility) {
                            ForEach(Visibility.allCases, id: \.self) { visibility in
                                Text(visibility.rawValue)
                                    .tag(visibility.value)
                            }
                        }
                        .tint(.black)
                    }
                    
                    HStack {
                        Image(systemName: "cloud")
                            .frame(width: 24)
                            .foregroundColor(.blue)
                        Text("Cloud Cover")
                        Spacer()
                        Picker("", selection: $cloudCover) {
                            ForEach(CloudCover.allCases, id: \.self) { cover in
                                Text(cover.rawValue)
                                    .tag(cover.value)
                            }
                        }
                        .tint(.black)
                    }
                }
                
                windSection
                
                sailsSection
                
                engineSection
                    .listSectionSpacing(.compact)
                
                notesSection
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                cancelButton
                saveButton
                keyboardToolbar
            }
            .onChange(of: focusedField) { oldValue, newValue in
                if let field = newValue {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(field, anchor: .center)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(field, anchor: .center)
                            }
                        }
                    }
                }
            }
        }
    }

    private func updateCoordinates() {
        let latitude = (latitudeDegrees + (latitudeMinutes / 60.0)) * (latitudeDirection ? 1 : -1)
        let longitude = (longitudeDegrees + (longitudeMinutes / 60.0)) * (longitudeDirection ? 1 : -1)
        
        // Prüfe zuerst die Gültigkeit
        if latitude < -90 || latitude > 90 {
            coordinatesError = "Invalid latitude: Must be between -90° and 90°"
            // Zeige einen Alert für den Benutzer
            withAnimation {
                latitudeDegrees = min(90, max(-90, latitudeDegrees))
            }
            return
        } else if longitude < -180 || longitude > 180 {
            coordinatesError = "Invalid longitude: Must be between -180° and 180°"
            // Zeige einen Alert für den Benutzer
            withAnimation {
                longitudeDegrees = min(180, max(-180, longitudeDegrees))
            }
            return
        } else if latitudeMinutes >= 60 || longitudeMinutes >= 60 {
            coordinatesError = "Invalid minutes: Must be less than 60"
            // Korrigiere die Minuten
            withAnimation {
                latitudeMinutes = min(59.99, latitudeMinutes)
                longitudeMinutes = min(59.99, longitudeMinutes)
            }
            return
        }
        
        // Lösche den Fehler, wenn alles gültig ist
        coordinatesError = nil
        
        // Aktualisiere die coordinates Property nur bei gültigen Werten
        coordinates = Coordinates(latitude: latitude, longitude: longitude)
    }
    
    private var timeAndPositionSection: some View {
        Section {
            HStack {
                Image(systemName: "clock")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Text("Date & Time")
                Spacer()
                DatePicker("Time", 
                    selection: $timestamp,
                    in: ...maxDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .labelsHidden()
            }
            
            coordinatesSection
        }
        .onAppear {
            // Initialisiere maxDate
            maxDate = Date()
        }
        // Aktualisiere maxDate jede Minute
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            maxDate = Date()
        }
    }
    
    private var coordinatesSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "location.fill")
                        .frame(width: 24)
                        .foregroundColor(.blue)
                    Text("Position")
                    Spacer()
                }
                
                // Latitude Input
                HStack {
                    Text("Lat")
                        .foregroundColor(.gray)
                    Spacer()
                    TextField("", value: Binding(
                        get: { latitudeDegrees },
                        set: { newValue in
                            latitudeDegrees = newValue
                            updateCoordinates()
                        }
                    ), formatter: degreesFormatter)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                        .focused($focusedField, equals: .latitudeDegrees)
                        .id(Field.latitudeDegrees)
                    Text("°")
                    TextField("", value: $latitudeMinutes, formatter: minutesFormatter)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)  // Etwas breiter für die Dezimalstellen
                        .focused($focusedField, equals: .latitudeMinutes)
                        .id(Field.latitudeMinutes)
                    Text("'")
                    Picker("", selection: $latitudeDirection) {
                        Text("N").tag(true)
                        Text("S").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 60)
                }
                
                // Longitude Input
                HStack {
                    Text("Lon")
                        .foregroundColor(.gray)
                    Spacer()
                    TextField("", value: Binding(
                        get: { longitudeDegrees },
                        set: { newValue in
                            longitudeDegrees = newValue
                            updateCoordinates()
                        }
                    ), formatter: degreesFormatter)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 50)
                        .focused($focusedField, equals: .longitudeDegrees)
                        .id(Field.longitudeDegrees)
                    Text("°")
                    TextField("", value: $longitudeMinutes, formatter: minutesFormatter)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)  // Etwas breiter für die Dezimalstellen
                        .focused($focusedField, equals: .longitudeMinutes)
                        .id(Field.longitudeMinutes)
                    Text("'")
                    Picker("", selection: $longitudeDirection) {
                        Text("E").tag(true)
                        Text("W").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 60)
                }
                
                // Fehleranzeige
                if let error = coordinatesError {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text(error)
                            .foregroundColor(.red)
                        .font(.caption)
                    }
                }
            }
        }
    }
    
    private var windSection: some View {
        Section("Wind") {
            HStack {
                Image(systemName: "arrow.up.left.circle")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Text("Direction")
                Spacer()
                Picker("", selection: $windDirection) {
                    ForEach(Compass.allCases, id: \.self) { direction in
                        Text(direction.rawValue.uppercased())
                            .tag(direction)
                    }
                }
                .tint(.black)
            }
            
            HStack {
                Image(systemName: "wind")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Text("Speed")
                Spacer()
                TextField("", value: Binding(
                    get: { windSpeed },
                    set: { newValue in
                        windSpeed = newValue
                        if let speed = newValue {
                            windSpeedBft = windSpeedToBeaufort(speed)
                        }
                    }
                ), formatter: numberFormatter)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 100)
                .focused($focusedField, equals: .windSpeed)
                .id(Field.windSpeed)
                Text("kts")
            }
            
            HStack {
                Image(systemName: "gauge")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Text("Force")
                Spacer()
                Picker("", selection: Binding(
                    get: { windSpeedBft },
                    set: { newValue in
                        windSpeedBft = newValue
                        windSpeed = beaufortToWindSpeed(newValue)
                    }
                )) {
                    ForEach(0...12, id: \.self) { bft in
                        Text("Bft \(bft)").tag(bft)
                    }
                }
                .tint(.black)
            }
        }
    }
    
    private var sailsSection: some View {
        Section("Sails") {
            HStack {
                Image(systemName: "sailboat")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Toggle("Main Sail", isOn: $sails.mainSail)
            }
            HStack {
                Image(systemName: "wind")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Toggle("Jib", isOn: $sails.jib)
            }
            HStack {
                Image(systemName: "wind")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Toggle("Genoa", isOn: $sails.genoa)
            }
            HStack {
                Image(systemName: "wind")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Toggle("Spinnaker", isOn: $sails.spinnaker)
            }
            
            HStack {
                Image(systemName: "minus.circle")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Text("Reefing")
                Spacer()
                HStack(spacing: 16) {
                    Button {
                        if sails.reefing > 0 {
                            sails.reefing -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title2)
                            .foregroundColor(sails.reefing > 0 ? .accentColor : .gray.opacity(0.3))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    
                    Text("\(sails.reefing)")
                        .font(.title3)
                        .frame(minWidth: 30)
                        .multilineTextAlignment(.center)
                    
                    Button {
                        if sails.reefing < Sails.maxReefing {
                            sails.reefing += 1
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(sails.reefing < Sails.maxReefing ? .accentColor : .gray.opacity(0.3))
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var engineSection: some View {
        Section("Engine") {
            HStack {
                Image(systemName: "engine.combustion")
                    .frame(width: 24)
                    .foregroundColor(.blue)
                Picker("", selection: $engineState) {
                    Text("Off").tag(EngineState.off)
                    Text("On").tag(EngineState.on)
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private var notesSection: some View {
        Section("Notes") {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Image(systemName: "note.text")
                        .frame(width: 24)
                        .foregroundColor(.blue)
                        .padding(.top, 10)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .focused($focusedField, equals: .notes)
                        .id(Field.notes)
                }
            }
        }
    }
    
    private var cancelButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
                dismiss()
            }
        }
    }
    
    private var saveButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: saveEntry) {
                Text("Save")
            }
            .disabled(magneticCourseError != nil || cogError != nil)
        }
    }
    
    private var keyboardToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .keyboard) {
            Button(action: moveToPreviousField) {
                Image(systemName: "chevron.up")
            }
            .disabled(!canMovePrevious)
            
            Button(action: moveToNextField) {
                Image(systemName: "chevron.down")
            }
            .disabled(!canMoveNext)
            
            Spacer()
            
            Button("Done") {
                focusedField = nil
            }
        }
    }
    
    private func saveEntry() {
        // Berechne die Koordinaten aus den Einzelwerten
        let latitude = (latitudeDegrees + (latitudeMinutes / 60.0)) * (latitudeDirection ? 1 : -1)
        let longitude = (longitudeDegrees + (longitudeMinutes / 60.0)) * (longitudeDirection ? 1 : -1)
        
        let updatedCoordinates = Coordinates(
            latitude: latitude,
            longitude: longitude
        )
        
        let updatedEntry = LogEntry(
            id: entry.id,
            timestamp: timestamp,
            coordinates: updatedCoordinates,
            distance: distance ?? 0,
            magneticCourse: magneticCourse ?? 0,
            courseOverGround: courseOverGround ?? 0,
            barometer: barometer ?? 1013.25,
            temperature: temperature ?? 0,
            visibility: visibility ?? 0,
            cloudCover: cloudCover ?? 0,
            wind: Wind(direction: windDirection, speedKnots: windSpeed ?? 0, beaufortForce: windSpeedBft),
            sailState: sailState,
            speed: speed ?? 0,
            engineState: engineState,
            maneuver: selectedManeuver,
            notes: notes.isEmpty ? nil : notes,
            sails: sails
        )
        
        logStore.updateEntry(updatedEntry)
        dismiss()
    }
    
    private var mapSection: some View {
        Section {
            MapView(
                locationManager: locationManager,
                tileManager: tileManager,
                coordinates: coordinates
            )
            .frame(height: 270)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
        .listSectionSpacing(.compact)
    }
}

extension Double {
    func splitToDegreesAndMinutes() -> (degrees: Double, minutes: Double) {
        let totalDegrees = abs(self)
        let degrees = floor(totalDegrees)
        let minutes = (totalDegrees - degrees) * 60
        return (degrees * (self >= 0 ? 1 : -1), minutes)
    }
    
    static func fromDegreesAndMinutes(degrees: Double, minutes: Double) -> Double {
        let absoluteValue = abs(degrees) + (abs(minutes) / 60.0)
        return absoluteValue * (degrees >= 0 ? 1 : -1)
    }
} 
