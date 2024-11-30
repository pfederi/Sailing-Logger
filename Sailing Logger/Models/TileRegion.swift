import MapKit

struct TileRegion: Equatable {
    let center: CLLocationCoordinate2D
    let span: MKCoordinateSpan
    
    var asMKCoordinateRegion: MKCoordinateRegion {
        MKCoordinateRegion(center: center, span: span)
    }
    
    init(region: MKCoordinateRegion) {
        self.center = region.center
        self.span = region.span
    }
    
    init(center: CLLocationCoordinate2D, span: MKCoordinateSpan) {
        self.center = center
        self.span = span
    }
    
    static func == (lhs: TileRegion, rhs: TileRegion) -> Bool {
        lhs.center.latitude == rhs.center.latitude &&
        lhs.center.longitude == rhs.center.longitude &&
        lhs.span.latitudeDelta == rhs.span.latitudeDelta &&
        lhs.span.longitudeDelta == rhs.span.longitudeDelta
    }
} 