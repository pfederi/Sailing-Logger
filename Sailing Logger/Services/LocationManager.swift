import Foundation
import CoreLocation

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: Coordinates?
    @Published var lastKnownLocation: Coordinates?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10
        
        if let savedLat = UserDefaults.standard.object(forKey: "LastKnownLatitude") as? Double,
           let savedLon = UserDefaults.standard.object(forKey: "LastKnownLongitude") as? Double {
            lastKnownLocation = Coordinates(latitude: savedLat, longitude: savedLon)
        }
        
        manager.requestWhenInUseAuthorization()
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
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
} 