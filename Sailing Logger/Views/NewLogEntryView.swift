import SwiftUI
import MapKit
import WebKit
import UserNotifications

struct NewLogEntryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var logStore: LogStore
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var themeManager: ThemeManager
    
    private var voyage: Voyage? {
        logStore.currentVoyage
    }
    
    @State private var timestamp = Date()
    @State private var coordinates: Coordinates
    
    @State private var magneticCourse: Double? = nil
    @State private var courseOverGround: Double? = nil
    @State private var distance: Double? = nil
    @State private var barometer: Double? = nil
    @State private var temperature: Double? = nil
    @State private var visibility: Visibility? = nil
    @State private var cloudCover: Int? = nil
    @State private var windDirection: Compass? = nil
    @State private var windSpeed: Double? = nil {
        didSet {
            if let speed = windSpeed {
                windSpeedBft = windSpeedToBeaufort(speed)
            }
        }
    }
    @State private var windSpeedBft: Int = 0
    @State private var sailState: SailState = .none
    @State private var speed: Double? = nil
    @State private var engineState: EngineState = .off {
        didSet {
            if engineState == .on {
                withAnimation {
                    sails.mainSail = false
                    sails.jib = false
                    sails.genoa = false
                    sails.spinnaker = false
                    sails.reefing = 0
                    sailState = .none
                }
            }
        }
    }
    @State private var notes: String = ""
    @State private var isLoadingWeather = false
    @State private var magneticCourseError: String? = nil
    @State private var cogError: String? = nil
    @State private var sails = Sails(
        mainSail: true,
        jib: true,
        genoa: false,
        spinnaker: false
    )
    @State private var weatherDataLoaded = false
    @State private var selectedManeuver: Maneuver? = nil
    @State private var wind = Wind(direction: .none, speedKnots: 0, beaufortForce: 0)
    
    @State private var latitudeDegrees: Double = 0
    @State private var latitudeMinutes: Double = 0
    @State private var longitudeDegrees: Double = 0
    @State private var longitudeMinutes: Double = 0
    @State private var latitudeDirection: Bool = true  // true = N, false = S
    @State private var longitudeDirection: Bool = true  // true = E, false = W
    @State private var coordinatesError: String?
    
    @FocusState private var focusedField: Field?
    
    @State private var maxDate = Date()
    
    @State private var mapView: MKMapView?
    
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
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()
    
    init(logStore: LogStore, locationManager: LocationManager, tileManager: OpenSeaMapTileManager, themeManager: ThemeManager) {
        self.logStore = logStore
        self.locationManager = locationManager
        self.tileManager = tileManager
        self.themeManager = themeManager
        
        let location = locationManager.currentLocation ?? locationManager.lastKnownLocation ?? Coordinates(latitude: 0, longitude: 0)
        _coordinates = State(initialValue: location)
        
        if let location = locationManager.currentLocation {
            let (latDeg, latMin) = abs(location.latitude).splitToDegreesAndMinutes()
            let (lonDeg, lonMin) = abs(location.longitude).splitToDegreesAndMinutes()
            
            _latitudeDegrees = State(initialValue: latDeg)
            _latitudeMinutes = State(initialValue: latMin)
            _longitudeDegrees = State(initialValue: lonDeg)
            _longitudeMinutes = State(initialValue: lonMin)
            _latitudeDirection = State(initialValue: location.latitude >= 0)
            _longitudeDirection = State(initialValue: location.longitude >= 0)
        } else {
            _latitudeDegrees = State(initialValue: 0)
            _latitudeMinutes = State(initialValue: 0)
            _longitudeDegrees = State(initialValue: 0)
            _longitudeMinutes = State(initialValue: 0)
            _latitudeDirection = State(initialValue: true)
            _longitudeDirection = State(initialValue: true)
        }
    }
    
    private func fetchWeatherData() {
        let apiKey = themeManager.openWeatherApiKey
        guard !apiKey.isEmpty else { return }
        
        isLoadingWeather = true
        let url = URL(string: "https://api.openweathermap.org/data/2.5/weather?lat=\(coordinates.latitude)&lon=\(coordinates.longitude)&appid=\(apiKey)&units=metric")!
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            isLoadingWeather = false
            
            guard let data = data else { return }
            
            do {
                let weather = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
                DispatchQueue.main.async {
                    // Update weather related fields
                    self.barometer = weather.main.pressure
                    self.visibility = Visibility.from(nauticalMiles: min(10, Int(Double(weather.visibility) / 1852.0)))
                    self.cloudCover = CloudCover.from(oktas: Int((Double(weather.clouds.all) / 100.0) * 8.0)).value
                    self.windDirection = Compass.from(degrees: weather.wind.deg)
                    // Setze zuerst windSpeedBft auf 0, damit der didSet von windSpeed korrekt funktioniert
                    self.windSpeedBft = 0
                    self.windSpeed = weather.wind.speed * 1.94384  // Convert m/s to knots
                    self.weatherDataLoaded = true
                    self.temperature = weather.main.temp
                }
            } catch {
                print("Weather decoding error: \(error)")
            }
        }.resume()
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
    
    private func createNewEntry() -> LogEntry {
        let latitude = (latitudeDegrees + (latitudeMinutes / 60.0)) * (latitudeDirection ? 1 : -1)
        let longitude = (longitudeDegrees + (longitudeMinutes / 60.0)) * (longitudeDirection ? 1 : -1)
        
        return LogEntry(
            id: UUID(),
            timestamp: timestamp,
            coordinates: Coordinates(latitude: latitude, longitude: longitude),
            distance: distance ?? 0,
            magneticCourse: magneticCourse ?? 0,
            courseOverGround: courseOverGround ?? 0,
            barometer: barometer ?? 0,
            temperature: temperature ?? 0,
            visibility: visibility?.value ?? 0,
            cloudCover: cloudCover ?? 0,
            wind: Wind(
                direction: windDirection ?? Compass.none,
                speedKnots: windSpeed ?? 0,
                beaufortForce: windSpeedBft
            ),
            speed: speed ?? 0,
            engineState: engineState,
            maneuver: selectedManeuver,
            notes: notes.isEmpty ? nil : notes,
            sails: sails
        )
    }
    
    private func saveEntryAndScheduleNotification() {
        let entry = createNewEntry()
        logStore.addEntry(entry)
        NotificationManager.shared.scheduleRepeatReminder()
        dismiss()
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
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                DatePicker("Time", 
                    selection: $timestamp,
                    in: ...maxDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }
            
            if coordinates.latitude == 0 && coordinates.longitude == 0 {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Waiting for location...")
                        .foregroundColor(.orange)
                }
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
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
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
                    Text("°")
                    TextField("", value: Binding(
                        get: { latitudeMinutes },
                        set: { newValue in
                            latitudeMinutes = newValue
                            updateCoordinates()
                        }
                    ), formatter: minutesFormatter)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .focused($focusedField, equals: .latitudeMinutes)
                    Text("'")
                    Picker("", selection: Binding(
                        get: { latitudeDirection },
                        set: { newValue in
                            latitudeDirection = newValue
                            updateCoordinates()
                        }
                    )) {
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
                    Text("°")
                    TextField("", value: Binding(
                        get: { longitudeMinutes },
                        set: { newValue in
                            longitudeMinutes = newValue
                            updateCoordinates()
                        }
                    ), formatter: minutesFormatter)
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 70)
                        .focused($focusedField, equals: .longitudeMinutes)
                    Text("'")
                    Picker("", selection: Binding(
                        get: { longitudeDirection },
                        set: { newValue in
                            longitudeDirection = newValue
                            updateCoordinates()
                        }
                    )) {
                        Text("E").tag(true)
                        Text("W").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 60)
                }
                
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
    
    private var mapSection: some View {
        Section {
            MapView(
                locationManager: locationManager,
                tileManager: tileManager,
                coordinates: coordinates,
                logEntries: logStore.entries
            )
            .frame(height: 270)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .onAppear {
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = scene.windows.first,
                   let mapView = window.rootViewController?.view.subviews.first(where: { $0 is MKMapView }) as? MKMapView {
                    self.mapView = mapView
                }
            }
        }
        .listSectionSpacing(.compact)
    }
    
    private var notesSection: some View {
        Section("Notes") {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Image(systemName: "note.text")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                        .padding(.top, 12)
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .focused($focusedField, equals: .notes)
                        .id(Field.notes)
                        .onChange(of: notes) { _, _ in
                            // Aktualisiere die Map sofort wenn sich die Notes ändern
                            if let mapView = mapView {
                                EasterEggService.addOrcaIfMentioned(
                                    mapView: mapView,
                                    logEntries: [createNewEntry()]
                                )
                            }
                        }
                }
            }
        }
    }
    
    var body: some View {
        Form {
            timeAndPositionSection
                .listSectionSpacing(.compact)
            
            mapSection
            
            Section {
                HStack {
                    Image(systemName: "arrow.triangle.swap")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text("Distance")
                    Spacer()
                    TextField("", value: $distance, formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .focused($focusedField, equals: .distance)
                    Text("nm")
                }
            }
            .listSectionSpacing(.compact)
            
            Section("Maneuvers") {
                HStack {
                    Image(systemName: "helm")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
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
                    .tint(MaritimeColors.navy(for: colorScheme))
                }
            }
            
            Section("Conditions") {
                HStack {
                    Image(systemName: "safari")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text("C°")
                    Spacer()
                    TextField("", value: courseBinding(for: $magneticCourse, error: $magneticCourseError), formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .focused($focusedField, equals: .magneticCourse)
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
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text("COG")
                    Spacer()
                    TextField("", value: courseBinding(for: $courseOverGround, error: $cogError), formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .focused($focusedField, equals: .courseOverGround)
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
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text("SOG")
                    Spacer()
                    TextField("", value: $speed, formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .focused($focusedField, equals: .speed)
                    Text("kts")
                }
                
                HStack {
                    Image(systemName: "barometer")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text("Barometer")
                    if weatherDataLoaded {
                        Text("API")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(MaritimeColors.navy(for: colorScheme))
                            .baselineOffset(14)
                            .padding(.leading, -4)
                    }
                    Spacer()
                    TextField("", value: $barometer, formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .focused($focusedField, equals: .barometer)
                    Text("hPa")
                }
                
                HStack {
                    Image(systemName: "thermometer")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text("Temperature")
                    if weatherDataLoaded {
                        Text("API")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(MaritimeColors.navy(for: colorScheme))
                            .baselineOffset(14)
                            .padding(.leading, -4)
                    }
                    Spacer()
                    TextField("", value: $temperature, formatter: numberFormatter)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .focused($focusedField, equals: .temperature)
                    Text("°C")
                }
                
                HStack {
                    Image(systemName: "eye")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text("Visibility")
                    if weatherDataLoaded {
                        Text("API")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(MaritimeColors.navy(for: colorScheme))
                            .baselineOffset(14)
                            .padding(.leading, -4)
                    }
                    Spacer()
                    Picker("", selection: $visibility) {
                        Text("Select Visibility").tag(nil as Visibility?)
                        ForEach(Visibility.allCases, id: \.self) { visibility in
                            Text(visibility.rawValue)
                                .tag(Optional(visibility))
                        }
                    }
                    .tint(MaritimeColors.navy(for: colorScheme))
                }
                
                HStack {
                    Image(systemName: "cloud")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text("Cloud Cover")
                    if weatherDataLoaded {
                        Text("API")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(MaritimeColors.navy(for: colorScheme))
                            .baselineOffset(14)
                            .padding(.leading, -4)
                    }
                    Spacer()
                    Picker("", selection: $cloudCover) {
                        Text("Select Cloud Cover").tag(nil as Int?)
                        ForEach(CloudCover.allCases, id: \.self) { cover in
                            Text(cover.rawValue)
                                .tag(Optional(cover.value))
                        }
                    }
                    .tint(MaritimeColors.navy(for: colorScheme))
                }
            }
            
            Section("Wind") {
                HStack {
                    Image(systemName: "arrow.up.left.circle")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text("Direction")
                    if weatherDataLoaded {
                        Text("API")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(MaritimeColors.navy(for: colorScheme))
                            .baselineOffset(14)
                            .padding(.leading, -4)
                    }
                    Spacer()
                    Picker("", selection: $windDirection) {
                        Text("Select Direction").tag(nil as Compass?)
                        ForEach(Compass.allCases, id: \.self) { direction in
                            Text(direction.rawValue.uppercased())
                                .tag(Optional(direction))
                        }
                    }
                    .tint(MaritimeColors.navy(for: colorScheme))
                }
                
                HStack {
                    Image(systemName: "wind")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Text("Speed")
                    if weatherDataLoaded {
                        Text("API")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(MaritimeColors.navy(for: colorScheme))
                            .baselineOffset(14)
                            .padding(.leading, -4)
                    }
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
                    Text("kts")
                }
                
                HStack {
                    Image(systemName: "gauge")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Spacer()
                    Picker("Force", selection: Binding(
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
                    .tint(MaritimeColors.navy(for: colorScheme))
                }
            }
            
            Section("Sails") {
                HStack {
                    Image(systemName: "sailboat")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Toggle("Main Sail", isOn: $sails.mainSail)
                        .disabled(engineState == .on)
                }
                HStack {
                    Image(systemName: "wind")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Toggle("Jib", isOn: $sails.jib)
                        .disabled(engineState == .on)
                }
                HStack {
                    Image(systemName: "wind")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Toggle("Genoa", isOn: $sails.genoa)
                        .disabled(engineState == .on)
                }
                HStack {
                    Image(systemName: "wind")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Toggle("Spinnaker", isOn: $sails.spinnaker)
                        .disabled(engineState == .on)
                }
                
                HStack {
                    Image(systemName: "minus.circle")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
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
            
            Section("Engine") {
                HStack {
                    Image(systemName: "engine.combustion")
                        .frame(width: 24)
                        .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    Picker("Engine", selection: $engineState) {
                        Text("Off").tag(EngineState.off)
                        Text("On").tag(EngineState.on)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: engineState) { _, newValue in
                        if newValue == .on {
                            withAnimation {
                                sails.mainSail = false
                                sails.jib = false
                                sails.genoa = false
                                sails.spinnaker = false
                                sails.reefing = 0
                                sailState = .none
                            }
                        }
                    }
                }
            }
            
            notesSection
            
            HStack {
                Text("Fields marked with ")
                + Text("API").foregroundColor(MaritimeColors.navy(for: colorScheme))
                + Text(" are automatically filled with OpenWeather data when available.")
            }
            .font(.caption)
            .listRowBackground(Color.clear)
        }
        .navigationTitle("New Entry")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    saveEntryAndScheduleNotification()
                }) {
                    Text("Save")
                    .fontWeight(.semibold)
                }
                .disabled(locationManager.currentLocation == nil)
            }
            
            // Keyboard Navigation hinzufügen
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
        .onAppear {
            fetchWeatherData()
            // Aktualisiere Koordinaten wenn verfügbar
            if let location = locationManager.currentLocation {
                coordinates = location
                let (latDeg, latMin) = abs(location.latitude).splitToDegreesAndMinutes()
                let (lonDeg, lonMin) = abs(location.longitude).splitToDegreesAndMinutes()
                
                latitudeDegrees = latDeg
                latitudeMinutes = latMin
                longitudeDegrees = lonDeg
                longitudeMinutes = lonMin
                latitudeDirection = location.latitude >= 0
                longitudeDirection = location.longitude >= 0
            }
        }
        .onChange(of: locationManager.currentLocation) { oldValue, newValue in
            if let location = newValue {
                coordinates = location
                let (latDeg, latMin) = abs(location.latitude).splitToDegreesAndMinutes()
                let (lonDeg, lonMin) = abs(location.longitude).splitToDegreesAndMinutes()
                
                latitudeDegrees = latDeg
                latitudeMinutes = latMin
                longitudeDegrees = lonDeg
                longitudeMinutes = lonMin
                latitudeDirection = location.latitude >= 0
                longitudeDirection = location.longitude >= 0
            }
        }
    }
}

// Helper extension
extension Double {
    func toBeaufort() -> Double {
        switch self {
        case 0...0.2: return 0
        case 0.3...1.5: return 1
        case 1.6...3.3: return 2
        case 3.4...5.4: return 3
        case 5.5...7.9: return 4
        case 8.0...10.7: return 5
        case 10.8...13.8: return 6
        case 13.9...17.1: return 7
        case 17.2...20.7: return 8
        case 20.8...24.4: return 9
        case 24.5...28.4: return 10
        case 28.5...32.6: return 11
        default: return 12
        }
    }
}

extension Compass {
    private static let directions: [Compass] = [.n, .ne, .e, .se, .s, .sw, .w, .nw]
    
    static func from(degrees: Double) -> Compass {
        let normalized = (degrees + 360).truncatingRemainder(dividingBy: 360)
        let index = Int((normalized + 22.5) / 45) % 8
        return directions[index]
    }
}
