import Foundation
import CoreLocation
import BackgroundTasks
import UIKit

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: Coordinates?
    @Published var lastKnownLocation: Coordinates?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        
        if let savedLat = UserDefaults.standard.object(forKey: "LastKnownLatitude") as? Double,
           let savedLon = UserDefaults.standard.object(forKey: "LastKnownLongitude") as? Double {
            lastKnownLocation = Coordinates(latitude: savedLat, longitude: savedLon)
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedAlways:
            // Wenn wir "Always" bekommen und Background-Tracking aktiv sein sollte,
            // starte es neu
            if manager.allowsBackgroundLocationUpdates {
                enableBackgroundTracking(interval: UserDefaults.standard.integer(forKey: "trackingInterval"))
            }
        case .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("Location access denied or restricted")
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func startBackgroundTracking(interval: Int) {
        print("🚀 Starting background tracking with interval: \(interval) seconds")
        
        // Überprüfe zuerst die Berechtigung
        switch authorizationStatus {
        case .authorizedAlways:
            enableBackgroundTracking(interval: interval)
        case .authorizedWhenInUse:
            // Wenn wir nur "When in Use" haben, fragen wir nach "Always"
            DispatchQueue.main.async {
                self.manager.requestAlwaysAuthorization()
            }
        case .notDetermined:
            // Für nicht determinierte Fälle, starte mit der Basis-Berechtigung
            DispatchQueue.main.async {
                self.manager.requestWhenInUseAuthorization()
            }
        default:
            print("❌ Location access denied or restricted")
        }
    }
    
    private func enableBackgroundTracking(interval: Int) {
        // Aktiviere Background Updates
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        
        // Verhindere automatisches Pausieren
        manager.pausesLocationUpdatesAutomatically = false
        
        // Stoppe zuerst alle laufenden Updates
        manager.stopUpdatingLocation()
        
        // Konfiguriere die Updates
        manager.desiredAccuracy = interval <= 300 ? kCLLocationAccuracyBest : kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = Double(max(10, interval / 2))
        
        // Starte die Updates
        manager.startUpdatingLocation()
        
        print("📍 Background tracking enabled with:")
        print("   Interval: \(interval) seconds")
        print("   Distance filter: \(manager.distanceFilter)m")
        print("   Accuracy: \(manager.desiredAccuracy)")
        print("   Background Updates: \(manager.allowsBackgroundLocationUpdates)")
        print("   Shows Indicator: \(manager.showsBackgroundLocationIndicator)")
    }
    
    func stopBackgroundTracking() {
        print("🛑 Stopping background tracking")
        
        // Stoppe Updates
        manager.stopUpdatingLocation()
        
        // Setze die Konfiguration zurück
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        manager.pausesLocationUpdatesAutomatically = true
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        
        // Starte normale Updates neu
        manager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            currentLocation = Coordinates(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            lastKnownLocation = currentLocation
            UserDefaults.standard.set(location.coordinate.latitude, forKey: "LastKnownLatitude")
            UserDefaults.standard.set(location.coordinate.longitude, forKey: "LastKnownLongitude")
            
            // Debug-Ausgabe
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "HH:mm:ss"
            let timeString = dateFormatter.string(from: Date())
            
            let appState = UIApplication.shared.applicationState
            let stateString = appState == .active ? "AKTIV" : (appState == .background ? "HINTERGRUND" : "INAKTIV")
            
            print("🗺 \(timeString) - Location Update (\(stateString))")
            print("   Lat: \(location.coordinate.latitude)")
            print("   Lon: \(location.coordinate.longitude)")
            print("   Accuracy: \(location.horizontalAccuracy)m")
            print("   Speed: \(location.speed)m/s")
            
            // Benachrichtige andere Komponenten über das Update
            NotificationCenter.default.post(
                name: Notification.Name("LocationUpdate"),
                object: nil,
                userInfo: ["location": location]
            )
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    func checkLocationStatus() {
        print("\n=== Location Status Check ===")
        print("Authorization: \(authorizationStatus.rawValue)")
        print("Background Updates: \(manager.allowsBackgroundLocationUpdates)")
        print("Shows Indicator: \(manager.showsBackgroundLocationIndicator)")
        print("Significant Changes Available: \(CLLocationManager.significantLocationChangeMonitoringAvailable())")
        print("Pauses Automatically: \(manager.pausesLocationUpdatesAutomatically)")
        print("Distance Filter: \(manager.distanceFilter)")
        print("Desired Accuracy: \(manager.desiredAccuracy)")
        print("==========================\n")
    }
} 