import SwiftUI
import MapKit

class LandscapeVoyageHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
}

struct VoyageLogViewContainer: UIViewControllerRepresentable {
    let voyage: Voyage
    let locationManager: LocationManager
    let tileManager: OpenSeaMapTileManager
    let logStore: LogStore
    let voyageStore: VoyageStore
    
    func makeUIViewController(context: Context) -> UIViewController {
        let landscapeController = LandscapeVoyageHostingController(
            rootView: VoyageLogView(
                voyage: voyage,
                locationManager: locationManager,
                tileManager: tileManager,
                logStore: logStore,
                voyageStore: voyageStore
            )
        )
        
        // Stellen Sie sicher, dass die Navigation Bar im Landscape-Modus sichtbar ist
        landscapeController.navigationItem.largeTitleDisplayMode = .never
        
        return landscapeController
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct VoyageLogView: View {
    let voyage: Voyage
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var tileManager: OpenSeaMapTileManager
    @ObservedObject var logStore: LogStore
    @ObservedObject var voyageStore: VoyageStore
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingScreenshot = false
    @State private var shareItems: [Any] = []
    @State private var selectedEntryId: UUID?
    
    private var routeCoordinates: [Coordinates] {
        return voyage.logEntries.map { $0.coordinates }
    }
    
    private var voyageStats: VoyageStats {
        calculateVoyageStats(voyage.logEntries)
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Voyage Info Header - unterschiedliche Höhen je nach Orientierung
                    VoyageHeaderView(voyage: voyage, stats: voyageStats)
                        .frame(height: UIDevice.current.orientation.isLandscape ? 
                            geometry.size.height * 0.35 : // Landscape: mehr Platz für Stats
                            geometry.size.height * 0.15)  // Portrait: kompakter
                    
                    // Map Section
                    RouteMapView(
                        locationManager: locationManager,
                        tileManager: tileManager,
                        routeCoordinates: routeCoordinates,
                        centerCoordinate: voyage.logEntries.last?.coordinates,
                        selectedEntryId: $selectedEntryId,
                        entries: voyage.logEntries
                    )
                    .frame(height: UIDevice.current.orientation.isLandscape ? 
                        geometry.size.height * 0.35 : // Landscape
                        geometry.size.height * 0.35)  // Portrait: gleiche Höhe
                    
                    // Table Section
                    LogEntriesTableView(
                        entries: voyage.logEntries,
                        selectedEntryId: $selectedEntryId
                    )
                    .frame(height: UIDevice.current.orientation.isLandscape ? 
                        geometry.size.height * 0.30 : // Landscape: etwas kleiner
                        geometry.size.height * 0.50)  // Portrait: mehr Platz für Einträge
                }
                .safeAreaInset(edge: .top) { Color.clear.frame(height: 0) }
            }
            .navigationTitle("Voyage Log - \(voyage.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(id: "share", placement: .navigationBarTrailing) {
                    Button {
                        createAndShareSnapshot()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(isGeneratingScreenshot)
                }
            }
            
            // Loading Overlay
            if isGeneratingScreenshot {
                LoadingOverlay()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }
    
    private func calculateVoyageStats(_ entries: [LogEntry]) -> VoyageStats {
        let totalDistance = entries.map { $0.distance }.max() ?? 0
        let maxSpeed = entries.map { $0.speed }.max() ?? 0
        let maxWindSpeed = entries.map { $0.wind.speedKnots }.max() ?? 0
        
        // Berechne Motormeilen aus den Teilstrecken
        let motorMiles = calculateMotorMiles(entries)
        
        let strongWindHours = entries.filter { $0.wind.beaufortForce > 5 }.count
        
        return VoyageStats(
            totalDistance: totalDistance,
            maxSpeed: maxSpeed,
            maxWindSpeed: maxWindSpeed,
            duration: calculateDuration(),
            numberOfEntries: entries.count,
            motorMiles: motorMiles,
            strongWindHours: strongWindHours
        )
    }
    
    private func calculateMotorMiles(_ entries: [LogEntry]) -> Double {
        let sortedEntries = entries.sorted { $0.timestamp < $1.timestamp }
        var motorMiles = 0.0
        var lastDistance = 0.0
        
        for entry in sortedEntries {
            if entry.engineState == .on {
                // Wenn Motor läuft, addiere die Differenz zur vorherigen Distanz
                motorMiles += max(0, entry.distance - lastDistance)
            }
            lastDistance = entry.distance
        }
        
        return motorMiles
    }
    
    private func calculateDuration() -> TimeInterval {
        if let end = voyage.endDate ?? voyage.logEntries.last?.timestamp {
            return end.timeIntervalSince(voyage.startDate)
        }
        return 0
    }
    
    private func createAndShareSnapshot() {
        isGeneratingScreenshot = true
        
        // Berechne die Gesamtbreite der Tabelle
        let tableWidth = 1924.0 // Summe aller Spaltenbreiten + Padding
        
        // Berechne die Grenzen der Route
        let coordinates = routeCoordinates.map { $0.toCLLocationCoordinate2D() }
        let rect = coordinates.reduce(MKMapRect.null) { rect, coordinate in
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            return rect.union(pointRect)
        }
        
        // Füge etwas Padding hinzu (10%)
        let paddedRect = rect.insetBy(dx: -rect.size.width * 0.1, dy: -rect.size.height * 0.1)
        
        // Erstellen Sie einen Snapshot der Karte
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(paddedRect)
        options.size = CGSize(width: tableWidth, height: 400)
        options.scale = UIScreen.main.scale
        
        // Konfiguriere die Map-Darstellung
        let config = MKStandardMapConfiguration()
        config.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = config
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        snapshotter.start { snapshot, error in
            guard let snapshot = snapshot else {
                self.isGeneratingScreenshot = false
                return
            }
            
            // Zeichne die Route auf den Snapshot
            UIGraphicsBeginImageContextWithOptions(snapshot.image.size, true, snapshot.image.scale)
            snapshot.image.draw(at: .zero)
            
            if let context = UIGraphicsGetCurrentContext() {
                let points = coordinates.map { snapshot.point(for: $0) }
                
                // Zeichne die Route
                context.setLineWidth(2.0)
                context.setStrokeColor(UIColor.blue.cgColor)
                
                for (index, point) in points.enumerated() {
                    if index == 0 {
                        context.move(to: point)
                    } else {
                        context.addLine(to: point)
                    }
                }
                context.strokePath()
                
                // Zeichne Start- und Endpunkte
                if let firstPoint = points.first {
                    context.setFillColor(UIColor.green.cgColor)
                    context.fillEllipse(in: CGRect(x: firstPoint.x - 5, y: firstPoint.y - 5, width: 10, height: 10))
                }
                
                if let lastPoint = points.last {
                    context.setFillColor(UIColor.red.cgColor)
                    context.fillEllipse(in: CGRect(x: lastPoint.x - 5, y: lastPoint.y - 5, width: 10, height: 10))
                }
            }
            
            let finalMapImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            // Erstelle den finalen Screenshot
            let content = VStack(spacing: 0) {
                // Header mit Voyage-Info
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        if let appIcon = Bundle.main.icon {
                            Image(uiImage: appIcon)
                                .resizable()
                                .frame(width: 40, height: 40)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        
                        Text("Sailing Logger")
                            .font(.title)
                    }
                    
                    Text(voyage.name)
                        .font(.title2)
                    Text("\(voyage.startDate.formatted(date: .long, time: .omitted)) - \(voyage.endDate?.formatted(date: .long, time: .omitted) ?? "ongoing")")
                        .font(.subheadline)
                    
                    // Stats
                    HStack(spacing: 20) {
                        StatItem(title: "Total Distance", value: String(format: "%.1f nm", voyageStats.totalDistance))
                        StatItem(title: "Max Speed", value: String(format: "%.1f kts", voyageStats.maxSpeed))
                        StatItem(title: "Max Wind", value: String(format: "%.1f kts", voyageStats.maxWindSpeed))
                        StatItem(title: "Duration", value: formatDuration(voyageStats.duration))
                        StatItem(title: "Entries", value: "\(voyageStats.numberOfEntries)")
                        StatItem(title: "Motor Miles", value: String(format: "%.1f nm", voyageStats.motorMiles))
                        StatItem(title: "Strong Wind Hours", value: "\(voyageStats.strongWindHours)")
                    }
                    .padding(.vertical)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.1))
                
                // Map
                if let mapImage = finalMapImage {
                    Image(uiImage: mapImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                
                // Table
                LogTableView(entries: voyage.logEntries)
            }
            .background(Color.white)
            
            let renderer = ImageRenderer(content: content)
            renderer.scale = 3.0
            
            if let image = renderer.uiImage {
                let fileName = "Voyage Log - \(voyage.name).png"
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                if let imageData = image.pngData() {
                    try? imageData.write(to: fileURL)
                    
                    DispatchQueue.main.async {
                        self.isGeneratingScreenshot = false
                        self.showShareSheet = true
                        self.shareItems = [fileURL]
                    }
                }
            } else {
                self.isGeneratingScreenshot = false
            }
        }
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }
}

struct VoyageStats {
    let totalDistance: Double
    let maxSpeed: Double
    let maxWindSpeed: Double
    let duration: TimeInterval
    let numberOfEntries: Int
    let motorMiles: Double
    let strongWindHours: Int
}

struct VoyageHeaderView: View {
    let voyage: Voyage
    let stats: VoyageStats
    
    var body: some View {
        VStack(spacing: 8) {
            if UIDevice.current.orientation.isLandscape {
                // Landscape: Titel und Datum nebeneinander
                HStack(spacing: 20) {
                    Text(voyage.name)
                        .font(.title2)
                        .lineLimit(1)
                    Text("\(formatDate(voyage.startDate)) - \(voyage.endDate.map(formatDate) ?? "ongoing")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                // Portrait: Titel und Datum untereinander
                Text(voyage.name)
                    .font(.title2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("\(formatDate(voyage.startDate)) - \(voyage.endDate.map(formatDate) ?? "ongoing")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Stats-Zeile
            HStack(spacing: 20) {
                StatsItem(title: "Total Distance", value: String(format: "%.1f nm", stats.totalDistance))
                StatsItem(title: "Max Speed", value: String(format: "%.1f kts", stats.maxSpeed))
                StatsItem(title: "Max Wind", value: String(format: "%.1f kts", stats.maxWindSpeed))
                StatsItem(title: "Duration", value: formatDuration(stats.duration))
                StatsItem(title: "Entries", value: "\(stats.numberOfEntries)")
                StatsItem(title: "Motor Miles", value: String(format: "%.1f nm", stats.motorMiles))
                StatsItem(title: "Strong Wind Hours", value: "\(stats.strongWindHours)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d. MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: interval) ?? ""
    }
}

struct StatsItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

struct StatItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

struct LoadingOverlay: View {
    var body: some View {
        Color.black.opacity(0.3)
            .edgesIgnoringSafeArea(.all)
            .overlay(
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Generating Image...")
                        .foregroundColor(.white)
                        .padding(.top, 10)
                        .font(.headline)
                }
                .frame(width: 150, height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.gray.opacity(0.7))
                )
            )
    }
}

struct LogTableView: View {
    let entries: [LogEntry]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Text("Time").frame(width: 80, alignment: .leading)
                Text("Position").frame(width: 180, alignment: .leading)
                Text("Dist").frame(width: 100, alignment: .leading)
                Text("C°").frame(width: 60, alignment: .leading)
                Text("COG").frame(width: 60, alignment: .leading)
                Text("SOG").frame(width: 80, alignment: .leading)
                Text("Wind Dir").frame(width: 80, alignment: .leading)
                Text("Wind Spd").frame(width: 100, alignment: .leading)
                Text("Bft").frame(width: 60, alignment: .leading)
                Text("Bar").frame(width: 80, alignment: .leading)
                Text("Temp").frame(width: 80, alignment: .leading)
                Text("Vis").frame(width: 60, alignment: .leading)
                Text("Cloud").frame(width: 60, alignment: .leading)
                Text("Sails").frame(width: 180, alignment: .leading)
                Text("Engine").frame(width: 60, alignment: .leading)
                Text("Maneuver").frame(width: 180, alignment: .leading)
                Text("Notes").frame(width: 400, alignment: .leading)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.2))
            .font(.system(size: 14, weight: .bold))
            
            // Entries
            ForEach(entries.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                HStack(spacing: 0) {
                    Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                        .frame(width: 80, alignment: .leading)
                    Text(entry.coordinates.formattedNautical())
                        .frame(width: 180, alignment: .leading)
                    Text(entry.distance == 0 ? "-" : String(format: "%.1f nm", entry.distance))
                        .frame(width: 100, alignment: .leading)
                    Text(entry.magneticCourse == 0 ? "-" : String(format: "%.1f°", entry.magneticCourse))
                        .frame(width: 60, alignment: .leading)
                    Text(entry.courseOverGround == 0 ? "-" : String(format: "%.1f°", entry.courseOverGround))
                        .frame(width: 60, alignment: .leading)
                    Text(entry.speed == 0 ? "-" : String(format: "%.1f kts", entry.speed))
                        .frame(width: 80, alignment: .leading)
                    Text(entry.wind.direction.rawValue.uppercased())
                        .frame(width: 80, alignment: .leading)
                    Text(entry.wind.speedKnots == 0 ? "-" : String(format: "%.1f kts", entry.wind.speedKnots))
                        .frame(width: 100, alignment: .leading)
                    Text(entry.wind.beaufortForce == 0 ? "-" : "\(entry.wind.beaufortForce)")
                        .frame(width: 60, alignment: .leading)
                    Text(entry.barometer == 0 ? "-" : String(format: "%.0f hPa", entry.barometer))
                        .frame(width: 80, alignment: .leading)
                    Text(entry.temperature == 0 ? "-" : String(format: "%.1f °C", entry.temperature))
                        .frame(width: 80, alignment: .leading)
                    Text(entry.visibility == 0 ? "-" : "\(entry.visibility)")
                        .frame(width: 60, alignment: .leading)
                    Text(entry.cloudCover == 0 ? "-" : "\(entry.cloudCover)")
                        .frame(width: 60, alignment: .leading)
                    Text(getSailsDescription(entry.sails))
                        .frame(width: 180, alignment: .leading)
                    Text(entry.engineState == .on ? "On" : "Off")
                        .frame(width: 60, alignment: .leading)
                    Text(entry.maneuver?.rawValue ?? "-")
                        .frame(width: 180, alignment: .leading)
                    Text(entry.notes ?? "-")
                        .frame(width: 400, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    Rectangle()
                        .fill(entries.firstIndex(of: entry)! % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))
                )
                .font(.system(size: 13))
            }
        }
    }
    
    private func getSailsDescription(_ sails: Sails) -> String {
        var parts: [String] = []
        if sails.mainSail { parts.append("Main") }
        if sails.jib { parts.append("Jib") }
        if sails.genoa { parts.append("Genoa") }
        if sails.spinnaker { parts.append("Spin") }
        if sails.reefing > 0 { parts.append("R\(sails.reefing)") }
        return parts.isEmpty ? "None" : parts.joined(separator: ", ")
    }
}

extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
} 