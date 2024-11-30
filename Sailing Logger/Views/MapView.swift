import SwiftUI
import MapKit

struct MapView: UIViewRepresentable {
    let locationManager: LocationManager
    let tileManager: OpenSeaMapTileManager
    var coordinates: Coordinates

    func makeUIView(context: Context) -> MKMapView {
        print("\n🗺 Creating MapView")
        
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Gesten-Kontrollen gleich am Anfang setzen
        mapView.isZoomEnabled = false      // Zoom-Gesten deaktivieren
        mapView.isScrollEnabled = true     // Scrollen/Verschieben erlauben
        mapView.isRotateEnabled = false    // Rotation deaktivieren
        mapView.isPitchEnabled = false     // Neigung deaktivieren
        
        // Deaktiviere Double-Tap
        if let doubleTapGesture = mapView.gestureRecognizers?.first(where: { $0 is UITapGestureRecognizer && ($0 as? UITapGestureRecognizer)?.numberOfTapsRequired == 2 }) {
            doubleTapGesture.isEnabled = false
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
        
        // Verwende die aktuellen Koordinaten
        let currentLocation = locationManager.currentLocation ?? Coordinates(latitude: 0, longitude: 0)
        
        // Füge Marker für aktuelle Position hinzu
        let annotation = MKPointAnnotation()
        annotation.coordinate = currentLocation.toCLLocationCoordinate2D()
        mapView.addAnnotation(annotation)
        
        // Starte mit Zoom-Level 14
        let span = 360.0 / pow(2.0, Double(14))
        let region = MKCoordinateRegion(
            center: currentLocation.toCLLocationCoordinate2D(),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        mapView.setRegion(region, animated: false)
        print("   Set region to: \(currentLocation.formattedNautical())")
        
        // Basiskarte konfigurieren
        mapView.mapType = .mutedStandard
        mapView.alpha = 1.0
        
        // Get documents directory path
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let tilesPath = documentsPath.appendingPathComponent("OpenSeaMapTiles")
        let channelURL = tilesPath.appendingPathComponent("channel.mbtiles")
        
        print("   Looking for MBTiles at: \(channelURL.path)")
        
        if FileManager.default.fileExists(atPath: channelURL.path) {
            print("✅ Found channel.mbtiles")
            
            let overlay = MBTilesOverlay(fileURL: channelURL)
            overlay.canReplaceMapContent = false
            mapView.addOverlay(overlay, level: .aboveLabels)
            print("   Added MBTiles overlay")
        } else {
            print("❌ channel.mbtiles not found - showing Apple Maps only")
        }
        
        // Hier die Änderungen:
        mapView.isZoomEnabled = false      // Zoom-Gesten deaktivieren
        mapView.isScrollEnabled = true     // Scrollen/Verschieben erlauben
        mapView.isRotateEnabled = false    // Rotation deaktivieren
        mapView.isPitchEnabled = false     // Neigung deaktivieren
        
        return mapView
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
                    latitudeDelta: 0.01,
                    longitudeDelta: 0.01
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
        var currentZoomIndex = 3  // Start bei Zoom-Level 14 (Index 3)

        init(_ parent: MapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 0.8
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
            let identifier = "Marker"
            
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            }
            
            if let markerView = annotationView as? MKMarkerAnnotationView {
                markerView.glyphText = "⛵️"
                markerView.markerTintColor = .clear
                markerView.glyphTintColor = .black
            }
            
            return annotationView
        }
    }
}
