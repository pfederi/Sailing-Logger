import SwiftUI
import MapKit

class LandscapeHostingController<Content: View>: UIHostingController<Content> {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }
}

struct DailyLogViewContainer: UIViewControllerRepresentable {
    let entries: [LogEntry]
    let date: String
    
    func makeUIViewController(context: Context) -> UIViewController {
        return LandscapeHostingController(
            rootView: DailyLogView(entries: entries, date: date)
        )
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

struct DailyLogView: View {
    let entries: [LogEntry]
    let date: String
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingScreenshot = false
    @StateObject private var locationManager = LocationManager()
    @StateObject private var tileManager = OpenSeaMapTileManager()
    @State private var shareItems: [Any] = []
    @State private var selectedEntryId: UUID?
    
    private var routeCoordinates: [Coordinates] {
        return entries.map { $0.coordinates }
    }
    
    var body: some View {
        ZStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Map Section
                    RouteMapView(
                        locationManager: locationManager,
                        tileManager: tileManager,
                        routeCoordinates: routeCoordinates,
                        centerCoordinate: entries.last?.coordinates,
                        selectedEntryId: $selectedEntryId,
                        entries: entries
                    )
                    .frame(height: geometry.size.height * 0.4)
                    
                    // Table Section
                    LogEntriesTableView(
                        entries: entries,
                        selectedEntryId: $selectedEntryId
                    )
                    .frame(height: geometry.size.height * 0.6)
                    .background(Color.white)
                    .clipped()
                }
            }
            .navigationTitle("Daily Log - \(date)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
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
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Generating Image...")
                        .foregroundColor(.white)
                        .padding(.top, 10)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 150, height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.gray.opacity(0.7))
                )
                .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height / 2)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: shareItems)
        }
    }
    
    private func createAndShareSnapshot() {
        isGeneratingScreenshot = true
        
        // Berechne die Gesamtbreite der Tabelle
        let tableWidth = 1965.0 // Summe aller Spaltenbreiten + Padding
        
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
        options.size = CGSize(width: tableWidth, height: 400) // Breite an Tabelle angepasst
        options.scale = UIScreen.main.scale
        
        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { snapshot, error in
            guard let snapshot = snapshot else {
                self.isGeneratingScreenshot = false
                return
            }
            
            // Zeichne die Punkte auf den Snapshot
            UIGraphicsBeginImageContextWithOptions(snapshot.image.size, true, snapshot.image.scale)
            snapshot.image.draw(at: .zero)
            
            if let context = UIGraphicsGetCurrentContext() {
                let points = coordinates.map { snapshot.point(for: $0) }
                
                // Zeichne jeden Punkt der Route
                for (index, point) in points.enumerated() {
                    // Wähle Farbe basierend auf Position (Start=grün, Ende=rot, dazwischen=blau)
                    if index == 0 {
                        context.setFillColor(UIColor.green.cgColor)
                    } else if index == points.count - 1 {
                        context.setFillColor(UIColor.red.cgColor)
                    } else {
                        context.setFillColor(UIColor.systemBlue.cgColor)
                    }
                    
                    // Zeichne den Punkt
                    context.fillEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
                }
            }
            
            let finalMapImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            // Screenshot erstellen
            let content = VStack(spacing: 0) {
                // Titel mit App-Icon und Name
                HStack {
                    if let iconDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
                       let primaryIconDictionary = iconDictionary["CFBundlePrimaryIcon"] as? [String: Any],
                       let iconFiles = primaryIconDictionary["CFBundleIconFiles"] as? [String],
                       let lastIcon = iconFiles.last,
                       let appIcon = UIImage(named: lastIcon) {
                        Image(uiImage: appIcon)
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Text("Sailing Logger")
                        .font(.headline)
                        .padding(.leading, 8)
                    Spacer()
                    Text("Daily Log - \(self.date)")
                        .font(.headline)
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(Color.gray.opacity(0.1))
                
                // Map Image
                if let mapImage = finalMapImage {
                    Image(uiImage: mapImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
                
                // Table Header
                HStack(spacing: 0) {
                    Text("Time").frame(width: 80, alignment: .leading)
                    Text("Position").frame(width: 180, alignment: .leading)
                    Text("Dist").frame(width: 120, alignment: .leading)
                    Text("C°").frame(width: 60, alignment: .leading)
                    Text("COG").frame(width: 80, alignment: .leading)
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
                ForEach(Array(self.entries.enumerated()), id: \.element.id) { index, entry in
                    HStack(spacing: 0) {
                        Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                            .frame(width: 80, alignment: .leading)
                        Text(entry.coordinates.formattedNautical())
                            .frame(width: 180, alignment: .leading)
                        Text(entry.distance == 0 ? "-" : String(format: "%.1f nm", entry.distance))
                            .frame(width: 120, alignment: .leading)
                        Text(entry.magneticCourse == 0 ? "-" : String(format: "%.1f°", entry.magneticCourse))
                            .frame(width: 60, alignment: .leading)
                        Text(entry.courseOverGround == 0 ? "-" : String(format: "%.1f°", entry.courseOverGround))
                            .frame(width: 80, alignment: .leading)
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
                    .background(index % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))
                    .font(.system(size: 13))
                }
            }
            .background(Color.white)
            
            let renderer = ImageRenderer(content: content)
            renderer.scale = 3.0
            
            if let image = renderer.uiImage {
                // Erstelle einen temporären Dateinamen
                let fileName = "Sailing Logger - \(date) at \(Date().formatted(date: .omitted, time: .complete)).png"
                let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                // Speichere das Bild als PNG
                if let imageData = image.pngData() {
                    try? imageData.write(to: fileURL)
                    
                    DispatchQueue.main.async {
                        self.shareImage = image
                        self.isGeneratingScreenshot = false
                        // Teile die Datei statt des UIImage
                        self.showShareSheet = true
                        self.shareImage = nil  // Clear the image reference
                        self.shareItems = [fileURL]  // Neue Property für die zu teilenden Items
                    }
                }
            } else {
                self.isGeneratingScreenshot = false
            }
        }
    }
}

struct LogEntriesTableView: View {
    let entries: [LogEntry]
    @Binding var selectedEntryId: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 0) {
                    // Header
                    LogTableHeaderView()
                    
                    // Entries
                    ScrollViewReader { scrollProxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                LogEntryRowView(
                                    entry: entry,
                                    isSelected: selectedEntryId == entry.id,
                                    isEvenRow: index % 2 == 0
                                )
                                .id(entry.id) // Wichtig für ScrollViewReader
                                .onTapGesture {
                                    selectedEntryId = entry.id
                                }
                            }
                        }
                        .onChange(of: selectedEntryId) { oldValue, newValue in
                            if let id = newValue {
                                withAnimation {
                                    scrollProxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct LogTableHeaderView: View {
    var body: some View {
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
    }
}

struct LogEntryRowView: View {
    let entry: LogEntry
    let isSelected: Bool
    let isEvenRow: Bool
    
    var body: some View {
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
                .fill(isSelected ? Color.blue.opacity(0.1) : (isEvenRow ? Color.clear : Color.gray.opacity(0.05)))
        )
        .font(.system(size: 13))
    }
}

// Helper function moved to global scope or extension
func getSailsDescription(_ sails: Sails) -> String {
    var parts: [String] = []
    if sails.mainSail { parts.append("Main") }
    if sails.jib { parts.append("Jib") }
    if sails.genoa { parts.append("Genoa") }
    if sails.spinnaker { parts.append("Spin") }
    if sails.reefing > 0 { parts.append("R\(sails.reefing)") }
    return parts.isEmpty ? "None" : parts.joined(separator: ", ")
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

class OfflineSeaMapOverlay: MKTileOverlay {
    let tileManager: OpenSeaMapTileManager
    
    init(tileManager: OpenSeaMapTileManager) {
        self.tileManager = tileManager
        super.init(urlTemplate: nil)
    }
    
    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        Task { @MainActor in
            if let (tileData, _) = tileManager.getTile(z: path.z, x: path.x, y: path.y) {
                result(tileData, nil)
            } else {
                result(nil, nil)
            }
        }
    }
}

struct RouteMapView: UIViewRepresentable {
    let locationManager: LocationManager
    let tileManager: OpenSeaMapTileManager
    var routeCoordinates: [Coordinates]
    var centerCoordinate: Coordinates?
    @Binding var selectedEntryId: UUID?
    let entries: [LogEntry]
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Deaktiviere Clustering
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultAnnotationViewReuseIdentifier
        )
        
        // Deaktiviere alle Interaktionen mit der Karte
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // Add offline OpenSeaMap tiles overlay
        let offlineOverlay = OfflineSeaMapOverlay(tileManager: tileManager)
        offlineOverlay.canReplaceMapContent = false
        mapView.addOverlay(offlineOverlay, level: .aboveLabels)
        
        // Add route points if coordinates exist
        if !routeCoordinates.isEmpty {
            for entry in entries {
                let annotation = RoutePointAnnotation(entry: entry)
                mapView.addAnnotation(annotation)
            }
        }
        
        // Deaktiviere Clustering explizit
        let config = MKStandardMapConfiguration()
        config.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = config
        
        // Set center if provided
        if let center = centerCoordinate?.toCLLocationCoordinate2D() {
            let span = MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            let region = MKCoordinateRegion(center: center, span: span)
            mapView.setRegion(region, animated: false)
        }
        
        // Füge Zoom-Controls hinzu
        let zoomInButton = UIButton(type: .system)
        zoomInButton.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        zoomInButton.addTarget(context.coordinator, action: #selector(Coordinator.zoomIn), for: .touchUpInside)
        
        let zoomOutButton = UIButton(type: .system)
        zoomOutButton.setImage(UIImage(systemName: "minus.circle.fill"), for: .normal)
        zoomOutButton.addTarget(context.coordinator, action: #selector(Coordinator.zoomOut), for: .touchUpInside)
        
        // Konfiguriere Buttons
        for button in [zoomInButton, zoomOutButton] {
            button.backgroundColor = .white
            button.tintColor = .systemBlue
            button.layer.cornerRadius = 20
            button.translatesAutoresizingMaskIntoConstraints = false
            mapView.addSubview(button)
        }
        
        // Positioniere Buttons
        NSLayoutConstraint.activate([
            zoomInButton.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -16),
            zoomInButton.topAnchor.constraint(equalTo: mapView.topAnchor, constant: 16),
            zoomInButton.widthAnchor.constraint(equalToConstant: 40),
            zoomInButton.heightAnchor.constraint(equalToConstant: 40),
            
            zoomOutButton.trailingAnchor.constraint(equalTo: mapView.trailingAnchor, constant: -16),
            zoomOutButton.topAnchor.constraint(equalTo: zoomInButton.bottomAnchor, constant: 8),
            zoomOutButton.widthAnchor.constraint(equalToConstant: 40),
            zoomOutButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // Add offline OpenSeaMap tiles overlay
        let offlineOverlay = OfflineSeaMapOverlay(tileManager: tileManager)
        offlineOverlay.canReplaceMapContent = false
        mapView.addOverlay(offlineOverlay, level: .aboveLabels)
        
        // Add route points
        if !routeCoordinates.isEmpty {
            for entry in entries {
                let annotation = RoutePointAnnotation(entry: entry)
                mapView.addAnnotation(annotation)
            }
        }
        
        // Update selected annotation
        if let selectedId = selectedEntryId,
           let selectedAnnotation = mapView.annotations.first(where: { ($0 as? RoutePointAnnotation)?.entry.id == selectedId }) {
            mapView.selectAnnotation(selectedAnnotation, animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(selectedEntryId: $selectedEntryId)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        let availableZoomLevels = [8, 10, 12, 14, 16]
        var currentZoomIndex = 3
        var selectedEntryId: Binding<UUID?>
        
        init(selectedEntryId: Binding<UUID?>) {
            self.selectedEntryId = selectedEntryId
            super.init()
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let routeAnnotation = annotation as? RoutePointAnnotation else { return nil }
            
            let identifier = "RoutePoint"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            }
            
            // Customize the point appearance
            annotationView?.markerTintColor = .systemBlue
            annotationView?.glyphImage = UIImage(systemName: "circle.fill")
            
            // Deaktiviere Clustering
            annotationView?.clusteringIdentifier = nil
            
            // Add time label to callout
            let timeLabel = UILabel()
            timeLabel.text = routeAnnotation.entry.timestamp.formatted(date: .omitted, time: .shortened)
            timeLabel.font = .systemFont(ofSize: 12)
            annotationView?.detailCalloutAccessoryView = timeLabel
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        @objc func zoomIn(_ sender: UIButton) {
            guard let mapView = sender.superview as? MKMapView,
                  currentZoomIndex < availableZoomLevels.count - 1 else { return }
            
            currentZoomIndex += 1
            let targetZoom = availableZoomLevels[currentZoomIndex]
            let span = 360.0 / pow(2.0, Double(targetZoom))
            let region = MKCoordinateRegion(
                center: mapView.region.center,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
            mapView.setRegion(region, animated: true)
        }
        
        @objc func zoomOut(_ sender: UIButton) {
            guard let mapView = sender.superview as? MKMapView,
                  currentZoomIndex > 0 else { return }
            
            currentZoomIndex -= 1
            let targetZoom = availableZoomLevels[currentZoomIndex]
            let span = 360.0 / pow(2.0, Double(targetZoom))
            let region = MKCoordinateRegion(
                center: mapView.region.center,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
            mapView.setRegion(region, animated: true)
        }
        
        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            if let routeAnnotation = annotation as? RoutePointAnnotation {
                DispatchQueue.main.async {
                    self.selectedEntryId.wrappedValue = routeAnnotation.entry.id
                }
            }
        }
    }
}

// Neue Klasse für die Annotation
class RoutePointAnnotation: MKPointAnnotation {
    let entry: LogEntry
    
    init(entry: LogEntry) {
        self.entry = entry
        super.init()
        self.coordinate = entry.coordinates.toCLLocationCoordinate2D()
        self.title = entry.timestamp.formatted(date: .omitted, time: .shortened)
    }
} 

