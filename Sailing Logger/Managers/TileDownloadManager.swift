import Foundation
import MapKit

@MainActor
class TileDownloadManager: ObservableObject {
    static let shared = TileDownloadManager()
    
    struct DownloadedRegion: Identifiable, Codable {
        let id: UUID
        let name: String
        let center: CLLocationCoordinate2D
        let span: MKCoordinateSpan
        let minZoom: Int
        let maxZoom: Int
        let tileCount: Int
        let size: Int // In MB
        let path: URL
        
        var bounds: MKCoordinateRegion {
            MKCoordinateRegion(center: center, span: span)
        }
        
        enum CodingKeys: String, CodingKey {
            case id, name, centerLat, centerLon, spanLat, spanLon
            case minZoom, maxZoom, tileCount, size, path
        }
        
        init(id: UUID = UUID(), name: String, bounds: MKCoordinateRegion, minZoom: Int, maxZoom: Int, tileCount: Int, size: Int, path: URL) {
            self.id = id
            self.name = name
            self.center = bounds.center
            self.span = bounds.span
            self.minZoom = minZoom
            self.maxZoom = maxZoom
            self.tileCount = tileCount
            self.size = size
            self.path = path
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(UUID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            let centerLat = try container.decode(Double.self, forKey: .centerLat)
            let centerLon = try container.decode(Double.self, forKey: .centerLon)
            center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
            let spanLat = try container.decode(Double.self, forKey: .spanLat)
            let spanLon = try container.decode(Double.self, forKey: .spanLon)
            span = MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
            minZoom = try container.decode(Int.self, forKey: .minZoom)
            maxZoom = try container.decode(Int.self, forKey: .maxZoom)
            tileCount = try container.decode(Int.self, forKey: .tileCount)
            size = try container.decode(Int.self, forKey: .size)
            path = try container.decode(URL.self, forKey: .path)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(center.latitude, forKey: .centerLat)
            try container.encode(center.longitude, forKey: .centerLon)
            try container.encode(span.latitudeDelta, forKey: .spanLat)
            try container.encode(span.longitudeDelta, forKey: .spanLon)
            try container.encode(minZoom, forKey: .minZoom)
            try container.encode(maxZoom, forKey: .maxZoom)
            try container.encode(tileCount, forKey: .tileCount)
            try container.encode(size, forKey: .size)
            try container.encode(path, forKey: .path)
        }
    }
    
    @Published var progress: Double = 0
    @Published var downloadedRegions: [DownloadedRegion] = []
    @Published var currentDownloadStatus: String = ""
    @Published var isLoading = false
    
    private let fileManager = FileManager.default
    private let documentsPath: URL
    private let urlSession: URLSession
    
    private init() {
        documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Konfiguriere URLSession für parallele Downloads
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 4
        urlSession = URLSession(configuration: config)
        
        loadDownloadedRegions()
    }
    
    func downloadRegion(name: String, region: MKCoordinateRegion, minZoom: Int, maxZoom: Int) async {
        isLoading = true
        progress = 0
        currentDownloadStatus = "Calculating tiles..."
        
        let regionFolder = documentsPath.appendingPathComponent("regions/\(name)")
        
        do {
            try fileManager.createDirectory(at: regionFolder, withIntermediateDirectories: true)
            
            var totalTiles = 0
            var downloadedTiles = 0
            
            // Berechne zuerst die Gesamtanzahl der Tiles
            for zoom in minZoom...maxZoom {
                let tiles = TileCalculator.calculateTiles(for: region, zoom: zoom)
                totalTiles += tiles.count
            }
            
            currentDownloadStatus = "Downloading \(totalTiles) tiles..."
            
            // Erstelle eine Task Group für parallele Downloads
            try await withThrowingTaskGroup(of: Bool.self) { group in
                for zoom in minZoom...maxZoom {
                    let tiles = TileCalculator.calculateTiles(for: region, zoom: zoom)
                    
                    // Füge maximal 4 parallele Downloads hinzu
                    var activeTasks = 0
                    for tile in tiles {
                        if activeTasks >= 4 {
                            // Warte auf einen fertigen Download
                            if try await group.next() == true {
                                downloadedTiles += 1
                                progress = Double(downloadedTiles) / Double(totalTiles)
                            }
                            activeTasks -= 1
                        }
                        
                        group.addTask {
                            return try await self.downloadTile(zoom: zoom, x: tile.x, y: tile.y, to: regionFolder)
                        }
                        activeTasks += 1
                    }
                    
                    // Warte auf die restlichen Downloads dieses Zoom-Levels
                    while let result = try await group.next() {
                        if result {
                            downloadedTiles += 1
                            progress = Double(downloadedTiles) / Double(totalTiles)
                        }
                    }
                }
            }
            
            // Speichere die Region-Informationen
            let newRegion = DownloadedRegion(
                name: name,
                bounds: region,
                minZoom: minZoom,
                maxZoom: maxZoom,
                tileCount: downloadedTiles,
                size: calculateFolderSize(regionFolder),
                path: regionFolder
            )
            
            // Speichere Metadaten
            let metadataURL = regionFolder.appendingPathComponent("metadata.json")
            let data = try JSONEncoder().encode(newRegion)
            try data.write(to: metadataURL)
            
            downloadedRegions.append(newRegion)
            currentDownloadStatus = "Download complete"
            
        } catch {
            currentDownloadStatus = "Error: \(error.localizedDescription)"
            print("Error downloading region: \(error)")
        }
        
        isLoading = false
    }
    
    private func downloadTile(zoom: Int, x: Int, y: Int, to folder: URL) async throws -> Bool {
        let tileURL = URL(string: "https://tile.openstreetmap.org/\(zoom)/\(x)/\(y).png")!
        let destinationURL = folder.appendingPathComponent("\(zoom)/\(x)/\(y).png")
        
        // Erstelle den Ordner für das Tile
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        // Lade das Tile herunter
        let (data, _) = try await urlSession.data(from: tileURL)
        try data.write(to: destinationURL)
        
        return true
    }
    
    private func calculateFolderSize(_ folder: URL) -> Int {
        guard let enumerator = fileManager.enumerator(at: folder, includingPropertiesForKeys: [.totalFileAllocatedSizeKey]) else { return 0 }
        
        var totalSize = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey]),
                  let size = resourceValues.totalFileAllocatedSize else { continue }
            totalSize += size
        }
        
        return totalSize / 1024 / 1024 // Konvertiere zu MB
    }
    
    func deleteRegion(_ region: DownloadedRegion) {
        do {
            try fileManager.removeItem(at: region.path)
            downloadedRegions.removeAll { $0.id == region.id }
        } catch {
            print("Error deleting region: \(error)")
        }
    }
    
    func clearCache() {
        do {
            for region in downloadedRegions {
                try fileManager.removeItem(at: region.path)
            }
            downloadedRegions.removeAll()
        } catch {
            print("Error clearing cache: \(error)")
        }
    }
    
    private func loadDownloadedRegions() {
        let regionsFolder = documentsPath.appendingPathComponent("regions")
        
        do {
            try fileManager.createDirectory(at: regionsFolder, withIntermediateDirectories: true)
            
            let regionFolders = try fileManager.contentsOfDirectory(
                at: regionsFolder,
                includingPropertiesForKeys: nil
            )
            
            downloadedRegions = regionFolders.compactMap { folder -> DownloadedRegion? in
                let metadataURL = folder.appendingPathComponent("metadata.json")
                guard fileManager.fileExists(atPath: metadataURL.path),
                      let data = try? Data(contentsOf: metadataURL),
                      let region = try? JSONDecoder().decode(DownloadedRegion.self, from: data) else {
                    return nil
                }
                return region
            }
        } catch {
            print("Error loading regions: \(error)")
            downloadedRegions = []
        }
    }
} 