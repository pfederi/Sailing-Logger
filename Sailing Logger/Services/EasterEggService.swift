import MapKit

// Custom Annotation für Orcas und Delfine
class OrcaAnnotation: MKPointAnnotation {
    // Leere Klasse als Marker-Typ für Orcas
}

class DolphinAnnotation: MKPointAnnotation {
    // Leere Klasse als Marker-Typ für Delfine
}

struct EasterEggService {
    static func addOrcaIfMentioned(mapView: MKMapView, logEntries: [LogEntry]) {
        // Entferne zuerst alle existierenden Meeressäuger-Annotationen
        let existingMarkers = mapView.annotations.filter { $0 is OrcaAnnotation || $0 is DolphinAnnotation }
        mapView.removeAnnotations(existingMarkers)
        
        print("🐋🐬 Checking \(logEntries.count) entries for marine mammals...")
        
        for entry in logEntries {
            guard let notes = entry.notes?.lowercased() else { 
                continue 
            }
            
            // Prüfe ob in den Notes ein Orca-Begriff vorkommt
            let orcaKeywords = [
                // Englisch
                "orca", "killer whale", "killerwhale",
                "whale", "whales",
                // Deutsch
                "wal", "wale", "killerwal", "killerwale",
                "schwertwal", "schwertwale",
                "meeressäuger"
            ]
            
            // Prüfe ob in den Notes ein Delfin-Begriff vorkommt
            let dolphinKeywords = [
                // Englisch
                "dolphin", "dolphins", "porpoise", "porpoises",
                // Deutsch
                "delfin", "delfine", "delphin", "delphine",
                "tümmler", "schweinswal", "schweinswale"
            ]
            
            let entryPosition = entry.coordinates.toCLLocationCoordinate2D()
            
            if orcaKeywords.contains(where: notes.contains) {
                print("🐋 Found orca mention in notes: \(notes)")
                
                // Positioniere den Orca leicht westlich (links) von der Position des Eintrags
                let orcaPosition = CLLocationCoordinate2D(
                    latitude: entryPosition.latitude,
                    longitude: entryPosition.longitude - 0.02
                )
                
                let annotation = OrcaAnnotation()
                annotation.coordinate = orcaPosition
                annotation.title = "🐋 Orca"
                annotation.subtitle = "Look, an Orca! 🌊"
                
                print("🐋 Adding orca at position: \(orcaPosition.latitude), \(orcaPosition.longitude)")
                mapView.addAnnotation(annotation)
            }
            
            if dolphinKeywords.contains(where: notes.contains) {
                print("🐬 Found dolphin mention in notes: \(notes)")
                
                // Positioniere den Delfin leicht östlich (rechts) von der Position des Eintrags
                let dolphinPosition = CLLocationCoordinate2D(
                    latitude: entryPosition.latitude,
                    longitude: entryPosition.longitude + 0.02
                )
                
                let annotation = DolphinAnnotation()
                annotation.coordinate = dolphinPosition
                annotation.title = "🐬 Dolphin"
                annotation.subtitle = "Look, Dolphins! 🌊"
                
                print("🐬 Adding dolphin at position: \(dolphinPosition.latitude), \(dolphinPosition.longitude)")
                mapView.addAnnotation(annotation)
            }
        }
        
        // Zusammenfassung am Ende
        let orcaCount = mapView.annotations.filter { $0 is OrcaAnnotation }.count
        let dolphinCount = mapView.annotations.filter { $0 is DolphinAnnotation }.count
        print("🐋🐬 Found \(orcaCount) orcas and \(dolphinCount) dolphins")
    }
}