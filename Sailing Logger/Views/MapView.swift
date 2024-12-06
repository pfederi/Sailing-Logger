import SwiftUI
import MapKit
import Network

struct MapView: UIViewRepresentable {
    let locationManager: LocationManager
    let tileManager: OpenSeaMapTileManager
    var coordinates: Coordinates
    @State private var isOnline: Bool = false
    
    func makeUIView(context: Context) -> MKMapView {
        print("\n🗺 Creating MapView")
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Gesten-Kontrollen
        configureGestures(mapView)
        
        // Zoom-Controls hinzufügen
        addZoomControls(mapView, context: context)
        
        // Konfiguriere Basiskarte
        setupBaseMap(mapView)
        
        // Füge Marker hinzu und setze Region
        setupInitialRegion(mapView)
        
        // Prüfe Netzwerkverbindung und lade entsprechende Karten
        checkConnectivityAndLoadMaps(mapView)
        
        return mapView
    }
    
    private func configureGestures(_ mapView: MKMapView) {
        mapView.isZoomEnabled = false
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        
        // Deaktiviere Double-Tap
        if let doubleTapGesture = mapView.gestureRecognizers?.first(where: { $0 is UITapGestureRecognizer && ($0 as? UITapGestureRecognizer)?.numberOfTapsRequired == 2 }) {
            doubleTapGesture.isEnabled = false
        }
    }
    
    private func setupBaseMap(_ mapView: MKMapView) {
        // Konfiguriere Apple Maps als Basiskarte
        mapView.mapType = .mutedStandard
        mapView.alpha = 1.0
        
        // Zeige Kompass und Points of Interest
        mapView.showsCompass = true
        mapView.pointOfInterestFilter = .includingAll
    }
    
    private func setupInitialRegion(_ mapView: MKMapView) {
        let currentLocation = locationManager.currentLocation ?? Coordinates(latitude: 0, longitude: 0)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = currentLocation.toCLLocationCoordinate2D()
        mapView.addAnnotation(annotation)
        
        let span = 360.0 / pow(2.0, Double(12))
        let region = MKCoordinateRegion(
            center: currentLocation.toCLLocationCoordinate2D(),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        mapView.setRegion(region, animated: false)
    }
    
    private func checkConnectivityAndLoadMaps(_ mapView: MKMapView) {
        // Zuerst Apple MapKit als Basiskarte
        mapView.mapType = .mutedStandard
        
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                if path.status == .satisfied {
                    print("🌐 Device is online - Loading online tiles...")
                    // Stelle sicher, dass Apple Maps sichtbar ist
                    mapView.mapType = .mutedStandard
                    self.loadOnlineOpenSeaMapTiles(mapView)
                } else {
                    print("📴 Device is offline - Loading offline tiles...")
                    // Stelle sicher, dass Apple Maps sichtbar ist
                    mapView.mapType = .mutedStandard
                    if !self.loadOfflineMBTiles(mapView) {
                        print("⚠️ No offline tiles available - Using Apple Maps as fallback")
                    }
                }
            }
        }
        monitor.start(queue: DispatchQueue.global())
    }
    
    private func loadOnlineOpenSeaMapTiles(_ mapView: MKMapView) {
        print("🌐 Starting to load online tiles...")
        
        // Basis-Layer (Landmassen)
        let baseTemplate = "https://tile.openstreetmap.org/{z}/{x}/{y}.png"
        let baseOverlay = MKTileOverlay(urlTemplate: baseTemplate)
        baseOverlay.canReplaceMapContent = true
        print("🗺 Adding base layer...")
        mapView.addOverlay(baseOverlay, level: .aboveRoads)
        
        // Nautische Daten mit TMS Y-Koordinaten-Umrechnung
        let seamarkTemplate = "https://tiles.openseamap.org/seamark/{z}/{x}/{tms_y}.png"
        let seamarkOverlay = TMSTileOverlay(urlTemplate: seamarkTemplate)
        seamarkOverlay.canReplaceMapContent = false
        print("⚓️ Adding seamark layer...")
        mapView.addOverlay(seamarkOverlay, level: .aboveLabels)
        
        print("✅ Added online OpenSeaMap tiles")
    }
    
    private func loadOfflineMBTiles(_ mapView: MKMapView) -> Bool {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tilesPath = documentsPath.appendingPathComponent("OpenSeaMapTiles")
        var overlaysAdded = false
        
        // Prüfe ob Tiles für die aktuelle Region verfügbar sind
        let coordinate = CLLocationCoordinate2D(
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )
        
        if tileManager.getRegionForCoordinate(coordinate) != nil {
            // Alle .mbtiles Dateien im Verzeichnis finden
            if let files = try? FileManager.default.contentsOfDirectory(at: tilesPath, 
                                                                      includingPropertiesForKeys: nil) {
                for file in files where file.pathExtension == "mbtiles" {
                    print("✅ Found offline tiles: \(file.lastPathComponent)")
                    let overlay = MBTilesOverlay(fileURL: file)
                    // Nur base layer sollte die Basiskarte ersetzen
                    overlay.canReplaceMapContent = file.lastPathComponent.contains("base")
                    mapView.addOverlay(overlay, level: .aboveLabels)
                    overlaysAdded = true
                }
            }
        }
        
        if !overlaysAdded {
            print("❌ No offline tiles available for current region")
        }
        
        return overlaysAdded
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Validiere die Koordinaten
        guard coordinates.latitude >= -90 && coordinates.latitude <= 90 &&
              coordinates.longitude >= -180 && coordinates.longitude <= 180 else {
            print("Invalid coordinates, skipping map update")
            return
        }
        
        // Update annotation position
        if let annotation = mapView.annotations.first as? MKPointAnnotation {
            annotation.coordinate = CLLocationCoordinate2D(
                latitude: coordinates.latitude,
                longitude: coordinates.longitude
            )
            
            // Update map region to center on new position
            let region = MKCoordinateRegion(
                center: annotation.coordinate,
                span: MKCoordinateSpan(
                    latitudeDelta: 360.0 / pow(2.0, Double(12)),
                    longitudeDelta: 360.0 / pow(2.0, Double(12))
                )
            )
            mapView.setRegion(region, animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        let availableZoomLevels = [8, 10, 12, 14, 16]  // Nur die MBTiles Zoom-Stufen
        var currentZoomIndex = 2  // Start bei Zoom-Level 12 (Index 2)

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                
                if let mbtiles = tileOverlay as? MBTilesOverlay {
                    // Offline MBTiles
                    let filename = mbtiles.fileURL.lastPathComponent
                    if filename.contains("base") {
                        renderer.alpha = 0.6  // Reduzierte Deckkraft für base layer
                    } else {
                        renderer.alpha = 0.8  // Andere Layer etwas transparenter
                    }
                } else {
                    // Online Tiles
                    if let template = tileOverlay.urlTemplate {
                        if template.contains("openstreetmap") {
                            renderer.alpha = 0.6
                        } else if template.contains("openseamap") {
                            renderer.alpha = 0.8
                        }
                    }
                }
                
                return renderer
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
            mapView.setRegion(region, animated: false)
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
            mapView.setRegion(region, animated: false)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            let identifier = "Location"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            }
            
            // Verwende das eigene SVG-Icon mit doppelter Größe und coral Farbe
            if let originalImage = UIImage(named: "route-marker") {
                let size = CGSize(width: originalImage.size.width * 2, height: originalImage.size.height * 2)
                UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                
                if let context = UIGraphicsGetCurrentContext() {
                    context.scaleBy(x: 2.0, y: 2.0)
                    originalImage.withTintColor(MaritimeColors.coralUI).draw(in: CGRect(origin: .zero, size: originalImage.size))
                }
                
                annotationView?.image = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
            }
            
            // Stelle sicher, dass der Ankerpunkt des Icons genau auf der Koordinate liegt
            annotationView?.centerOffset = CGPoint(x: 0, y: 0)
            
            return annotationView
        }
    }

    private func addZoomControls(_ mapView: MKMapView, context: Context) {
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
            button.tintColor = UIColor(MaritimeColors.navy)
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
        
        // Verstecke die Attribution Labels
        for subview in mapView.subviews {
            if let label = subview as? UILabel {
                label.isHidden = true
            }
            if let imageView = subview as? UIImageView {
                imageView.isHidden = true
            }
        }
        
        // Setze maximalen Zoom-Level
        let minDistance = 360.0 / pow(2.0, 16.0) // Zoom Level 16
        mapView.cameraZoomRange = MKMapView.CameraZoomRange(
            minCenterCoordinateDistance: minDistance * 111000, // Umrechnung in Meter
            maxCenterCoordinateDistance: .infinity
        )
    }
}

// Neue Klasse für TMS-Tiles
class TMSTileOverlay: MKTileOverlay {
    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        // Konvertiere y-Koordinate zu TMS Format
        let tms_y = (1 << path.z) - 1 - path.y
        
        // Ersetze {tms_y} im Template mit dem berechneten Wert
        let urlString = self.urlTemplate?
            .replacingOccurrences(of: "{z}", with: String(path.z))
            .replacingOccurrences(of: "{x}", with: String(path.x))
            .replacingOccurrences(of: "{tms_y}", with: String(tms_y))
        
        return URL(string: urlString!)!
    }
}