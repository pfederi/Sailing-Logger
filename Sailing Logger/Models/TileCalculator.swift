import MapKit

struct TileCalculator {
    static func calculateTiles(for region: MKCoordinateRegion, zoom: Int) -> [(x: Int, y: Int)] {
        let n = pow(2.0, Double(zoom))
        
        // Berechne die Grenzen mit Puffer
        let buffer = 0.2 // 20% Puffer für flüssigeres Scrollen
        let minLat = region.center.latitude - region.span.latitudeDelta * (0.5 + buffer)
        let maxLat = region.center.latitude + region.span.latitudeDelta * (0.5 + buffer)
        let minLon = region.center.longitude - region.span.longitudeDelta * (0.5 + buffer)
        let maxLon = region.center.longitude + region.span.longitudeDelta * (0.5 + buffer)
        
        // Konvertiere zu Tile-Koordinaten
        let minX = max(0, Int(floor((minLon + 180.0) / 360.0 * n)))
        let maxX = min(Int(n - 1), Int(floor((maxLon + 180.0) / 360.0 * n)))
        
        // Konvertiere Lat zu Y mit Mercator-Projektion
        func latToY(_ lat: Double) -> Int {
            let latRad = lat * .pi / 180.0
            let y = log(tan(latRad/2 + .pi/4))
            return max(0, min(Int(n - 1), Int(floor((1.0 - y / .pi) * n / 2.0))))
        }
        
        let minY = latToY(maxLat)
        let maxY = latToY(minLat)
        
        // Kapazität vorallozieren
        var tiles = [(x: Int, y: Int)]()
        tiles.reserveCapacity((maxX - minX + 1) * (maxY - minY + 1))
        
        // Tiles effizient generieren
        for x in minX...maxX {
            for y in minY...maxY {
                tiles.append((x: x, y: y))
            }
        }
        
        return tiles
    }
    
    static func coordinateToTile(latitude: Double, longitude: Double, zoom: Int) -> (x: Int, y: Int) {
        let n = pow(2.0, Double(zoom))
        let x = Int(floor((longitude + 180.0) / 360.0 * n))
        let y = Int(floor((1.0 - log(tan(latitude * .pi / 180.0) + 1.0 / cos(latitude * .pi / 180.0)) / .pi) / 2.0 * n))
        return (x: x, y: y)
    }
} 