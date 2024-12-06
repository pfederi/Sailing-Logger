import MapKit

// Custom Annotation für Orcas
class OrcaAnnotation: MKPointAnnotation {
    // Leere Klasse als Marker-Typ für Orcas
}

struct EasterEggService {
    static func addOrcasIfNaomiPresent(mapView: MKMapView, crew: [CrewMember]) {
        // Prüfe, ob Naomi im Crew Array ist
        let naomiPresent = crew.contains { $0.name.lowercased() == "naomi shepherd" }
        
        guard naomiPresent else { return }
        
        // Entferne ALLE existierenden Annotationen
        let allAnnotations = mapView.annotations
        mapView.removeAnnotations(allAnnotations)
        
        // Finde den Hauptmarker aus den entfernten Annotationen
        guard let marker = allAnnotations.first(where: { $0 is PositionAnnotation }) else { return }
        
        // Füge den Hauptmarker zuerst wieder hinzu
        mapView.addAnnotation(marker)
        
        let markerPosition = marker.coordinate
        print("Marker position: \(markerPosition)")
        
        // Vordefinierte Richtungen für die Orcas (in Grad)
        let directions = [45.0, 135.0, 225.0, 315.0] // NE, SE, SW, NW
        
        // Füge 1-3 Orcas in der Nähe hinzu
        let numberOfOrcas = Int.random(in: 1...3)
        var usedDirections = directions.shuffled()
        
        for i in 0..<numberOfOrcas {
            let direction = usedDirections[i] * .pi / 180.0 // Umrechnung in Radiant
            let distance = Double.random(in: 0.02...0.05)   // 2-5km
            
            // Berechne Position
            let latOffset = distance * cos(direction)
            let lonOffset = distance * sin(direction)
            
            let randomCoordinate = CLLocationCoordinate2D(
                latitude: markerPosition.latitude + latOffset,
                longitude: markerPosition.longitude + lonOffset
            )
            
            print("Orca \(i): direction=\(direction), distance=\(distance), final position=\(randomCoordinate)")
            
            let orcaAnnotation = OrcaAnnotation()
            orcaAnnotation.coordinate = randomCoordinate
            orcaAnnotation.title = "🐋 Orca"
            orcaAnnotation.subtitle = "Hi Naomi! 👋"
            
            mapView.addAnnotation(orcaAnnotation)
        }
        
        // Debug: Finale Überprüfung
        let finalAnnotations = mapView.annotations
        print("Final annotations count: \(finalAnnotations.count)")
        for (index, annotation) in finalAnnotations.enumerated() {
            print("Annotation \(index): type=\(type(of: annotation)), position=\(annotation.coordinate)")
        }
    }
} 