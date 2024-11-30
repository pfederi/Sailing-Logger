import Foundation
import SQLite3
import UIKit
import MapKit
import UserNotifications

@MainActor
class OpenSeaMapTileManager: NSObject, ObservableObject {
    private let fileManager = FileManager.default
    private let tilesDirectory: URL
    private var availableZoomLevels: [String: Set<Int>] = [:]  // Pro Region
    private var mbtilesDatabases: [String: URL] = [:]  // Pfade zu allen MBTiles-Dateien
    @Published var downloadProgress: Float = 0
    @Published var isDownloading = false
    @Published var isPreparing = false
    @Published var currentlyDownloading: String? = nil
    @Published var downloadedBytes: Int64 = 0
    @Published var totalBytes: Int64 = 0
    @Published var estimatedTimeRemaining: TimeInterval? = nil
    private var downloadStartTime: Date? = nil
    private var downloadTask: URLSessionDownloadTask? = nil
    private var progressObserver: NSKeyValueObservation?
    @Published var availableRegions: [String] = [
        "adria",
        "baltic",
        "channel",
        "gulfofbiscay",
        "magellan",
        "medieast",
        "mediwest",
        "northsea"
    ]
    
    private let baseURL = "https://ftp.gwdg.de/pub/misc/openstreetmap/openseamap/charts/mbtiles/OSM-OpenCPN2-"
    
    private var backgroundSession: URLSession!
    private var backgroundCompletionHandler: (() -> Void)?
    @Published var showDownloadStartedAlert = false
    
    override init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        tilesDirectory = documentsPath.appendingPathComponent("OpenSeaMapTiles")
        
        super.init()
        
        // I/O-Operationen auf Background-Thread
        Task.detached(priority: .userInitiated) {
            try? FileManager.default.createDirectory(at: self.tilesDirectory, withIntermediateDirectories: true)
            
            let config = URLSessionConfiguration.background(withIdentifier: "com.sailinglogger.tiledownload")
            config.allowsConstrainedNetworkAccess = true
            config.allowsExpensiveNetworkAccess = true
            config.waitsForConnectivity = true
            config.sessionSendsLaunchEvents = true
            config.isDiscretionary = false
            
            await MainActor.run {
                self.backgroundSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            }
            
            // Suche nach allen .mbtiles Dateien im Verzeichnis
            await self.loadAvailableMBTiles()
            
            // Berechtigungen für Benachrichtigungen anfordern
            await MainActor.run {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if granted {
                        print("Notification permission granted")
                    }
                }
            }
        }
    }
    
    private func loadAvailableMBTiles() async {
        do {
            let files = try fileManager.contentsOfDirectory(at: tilesDirectory, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "mbtiles" {
                let regionName = file.deletingPathExtension().lastPathComponent
                self.mbtilesDatabases[regionName] = file
                loadMetadata(for: regionName)
            }
        } catch {
            print("Error loading MBTiles: \(error)")
        }
    }
    
    private func loadMetadata(for region: String) {
        guard let dbURL = mbtilesDatabases[region] else { return }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            print("❌ Cannot open database for metadata")
            return
        }
        defer { sqlite3_close(db) }
        
        let query = "SELECT name, value FROM metadata"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Cannot prepare metadata statement")
            return
        }
        defer { sqlite3_finalize(statement) }
        
        print("\n=== MBTiles Metadata for \(region) ===")
        while sqlite3_step(statement) == SQLITE_ROW {
            let name = String(cString: sqlite3_column_text(statement, 0))
            let value = String(cString: sqlite3_column_text(statement, 1))
            print("\(name): \(value)")
        }
        print("=====================")
    }
    
    private func loadAvailableZoomLevels(for region: String) {
        guard let dbURL = mbtilesDatabases[region] else { return }
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            print("❌ Cannot open database for zoom levels")
            return
        }
        defer { sqlite3_close(db) }
        
        let query = """
            SELECT zoom_level, COUNT(*) as tile_count 
            FROM tiles 
            GROUP BY zoom_level 
            ORDER BY zoom_level
        """
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Cannot prepare zoom levels statement")
            return
        }
        defer { sqlite3_finalize(statement) }
        
        var levels = Set<Int>()
        print("\n=== Available Zoom Levels for \(region) ===")
        while sqlite3_step(statement) == SQLITE_ROW {
            let zoom = Int(sqlite3_column_int(statement, 0))
            let count = Int(sqlite3_column_int(statement, 1))
            levels.insert(zoom)
            print("Zoom level \(zoom): \(count) tiles")
        }
        availableZoomLevels[region] = levels
        print("=========================")
    }
    
    func getTile(z: Int, x: Int, y: Int) -> (Data, String)? {
        // Prüfe alle verfügbaren Regionen
        for (region, dbURL) in mbtilesDatabases {
            print("🔍 Checking region \(region) for tile z:\(z) x:\(x) y:\(y)")
            if let tileData = getTile(z: z, x: x, y: y, from: dbURL) {
                print("✅ Found tile in region \(region)")
                return (tileData, region)
            }
        }
        print("❌ No tile found in any region for z:\(z) x:\(x) y:\(y)")
        return nil
    }
    
    private func getTile(z: Int, x: Int, y: Int, from dbURL: URL) -> Data? {
        // Invertiere die y-Koordinate für TMS
        let n = 1 << z
        let invertedY = n - 1 - y
        
        print("🔄 Converting coordinates:")
        print("Original: z:\(z) x:\(x) y:\(y)")
        print("TMS: z:\(z) x:\(x) y:\(invertedY)")
        
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            print("❌ Cannot open database at \(dbURL.path)")
            return nil
        }
        defer { sqlite3_close(db) }
        
        let query = """
            SELECT tile_data 
            FROM tiles 
            WHERE zoom_level = ? 
            AND tile_column = ? 
            AND tile_row = ?
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            print("❌ Cannot prepare statement")
            return nil
        }
        defer { sqlite3_finalize(statement) }
        
        sqlite3_bind_int(statement, 1, Int32(z))
        sqlite3_bind_int(statement, 2, Int32(x))
        sqlite3_bind_int(statement, 3, Int32(invertedY))
        
        if sqlite3_step(statement) == SQLITE_ROW {
            guard let bytes = sqlite3_column_blob(statement, 0) else {
                print("❌ No blob data found")
                return nil
            }
            let length = sqlite3_column_bytes(statement, 0)
            print("✅ Found tile data of size \(length) bytes")
            return Data(bytes: bytes, count: Int(length))
        }
        
        print("❌ No tile found in database")
        return nil
    }
    
    func isAvailable() -> Bool {
        return !mbtilesDatabases.isEmpty
    }
    
    func isTileAvailableOffline(zoom: Int, x: Int, y: Int) -> Bool {
        // Prüfe ob die Tile in irgendeiner Region verfügbar ist
        for (_, dbURL) in mbtilesDatabases {
            var db: OpaquePointer?
            guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
                continue
            }
            defer { sqlite3_close(db) }
            
            // Invertiere die y-Koordinate für TMS
            let n = 1 << zoom
            let invertedY = n - 1 - y
            
            let query = """
                SELECT COUNT(*) 
                FROM tiles 
                WHERE zoom_level = ? 
                AND tile_column = ? 
                AND tile_row = ?
            """
            
            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
                continue
            }
            defer { sqlite3_finalize(statement) }
            
            sqlite3_bind_int(statement, 1, Int32(zoom))
            sqlite3_bind_int(statement, 2, Int32(x))
            sqlite3_bind_int(statement, 3, Int32(invertedY))
            
            if sqlite3_step(statement) == SQLITE_ROW {
                let count = sqlite3_column_int(statement, 0)
                if count > 0 {
                    return true
                }
            }
        }
        
        return false
    }
    
    func getRegionForCoordinate(_ coordinate: CLLocationCoordinate2D) -> String? {
        // Prüfe für jede Region, ob die Koordinate in den Bounds liegt
        for (region, dbURL) in mbtilesDatabases {
            if isCoordinateInRegion(coordinate, dbURL: dbURL) {
                return region
            }
        }
        return nil
    }
    
    func isRegionAvailable(_ coordinate: CLLocationCoordinate2D) -> Bool {
        // Prüfe ob es eine Region gibt, die diese Koordinate abdeckt
        // aber noch nicht heruntergeladen wurde
        // TODO: Implementiere die Prüfung gegen einen Server oder eine Liste verfügbarer Regionen
        return false
    }
    
    private func isCoordinateInRegion(_ coordinate: CLLocationCoordinate2D, dbURL: URL) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_close(db) }
        
        let query = "SELECT value FROM metadata WHERE name = 'bounds'"
        var statement: OpaquePointer?
        
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return false
        }
        defer { sqlite3_finalize(statement) }
        
        if sqlite3_step(statement) == SQLITE_ROW,
           let boundsStr = sqlite3_column_text(statement, 0) {
            let bounds = String(cString: boundsStr).split(separator: ",").map { Double($0.trimmingCharacters(in: .whitespaces)) ?? 0 }
            if bounds.count == 4 {
                let minLon = bounds[0]
                let minLat = bounds[1]
                let maxLon = bounds[2]
                let maxLat = bounds[3]
                
                return coordinate.longitude >= minLon && coordinate.longitude <= maxLon &&
                       coordinate.latitude >= minLat && coordinate.latitude <= maxLat
            }
        }
        
        return false
    }
    
    func hasTiles(for region: MKCoordinateRegion, zoom: Int) -> Bool {
        // Implementiere hier die Logik zur Überprüfung der verfügbaren Tiles
        // Zum Beispiel:
        return !mbtilesDatabases.isEmpty
    }
    
    private func getRegionNameForURL(_ region: String) -> String {
        switch region {
        case "magellan":
            return "MagellanStrait"
        case "medieast":
            return "MediEast"
        case "mediwest":
            return "MediWest"
        case "gulfofbiscay":
            return "GulfOfBiscay"
        case "northsea":
            return "NorthSea"
        default:
            return region.prefix(1).uppercased() + region.dropFirst()
        }
    }
    
    func downloadTiles(for region: String) async throws {
        guard !isDownloading else { return }
        
        self.isPreparing = true
        self.currentlyDownloading = region
        self.downloadProgress = 0
        self.downloadedBytes = 0
        self.totalBytes = 0
        self.downloadStartTime = Date()
        self.showDownloadStartedAlert = true
        
        let regionName = getRegionNameForURL(region)
        let downloadURL = URL(string: "\(baseURL)\(regionName).mbtiles")!
        
        // Konfiguriere Session
        let config = URLSessionConfiguration.default
        config.allowsConstrainedNetworkAccess = true
        config.allowsExpensiveNetworkAccess = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 3600
        
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        let downloadTask = session.downloadTask(with: downloadURL)
        self.downloadTask = downloadTask
        
        // Setze isPreparing auf false und isDownloading auf true
        self.isPreparing = false
        self.isDownloading = true
        
        downloadTask.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        
        self.isDownloading = false
        self.isPreparing = false
        self.currentlyDownloading = nil
        self.downloadProgress = 0
        self.downloadedBytes = 0
        self.totalBytes = 0
        self.estimatedTimeRemaining = nil
        self.downloadStartTime = nil
    }
    
    func isFileDownloaded(_ region: String) -> Bool {
        let fileURL = tilesDirectory.appendingPathComponent("\(region).mbtiles")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    func deleteTiles(for region: String) {
        // FileManager-Operation auf Background-Thread
        let fileURL = tilesDirectory.appendingPathComponent("\(region).mbtiles")
        Task.detached(priority: .userInitiated) {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
    
    deinit {
        progressObserver?.invalidate()
    }
}

extension OpenSeaMapTileManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let originalRegionName = downloadTask.originalRequest?.url?.lastPathComponent
            .replacingOccurrences(of: "OSM-OpenCPN2-", with: "")
            .replacingOccurrences(of: ".mbtiles", with: "") else { return }
        
        // Konvertiere den Regionsnamen zurück in das interne Format
        let regionName = originalRegionName.lowercased()
            .replacingOccurrences(of: "magellanstrait", with: "magellan")
            .replacingOccurrences(of: "medieast", with: "medieast")
            .replacingOccurrences(of: "mediwest", with: "mediwest")
            .replacingOccurrences(of: "gulfofbiscay", with: "gulfofbiscay")
            .replacingOccurrences(of: "northsea", with: "northsea")
        
        let destinationURL = tilesDirectory.appendingPathComponent("\(regionName).mbtiles")
        
        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: location, to: destinationURL)
            
            Task { @MainActor in
                self.isDownloading = false
                self.currentlyDownloading = nil
                self.downloadProgress = 1.0
                
                // Sende Benachrichtigung
                let content = UNMutableNotificationContent()
                content.title = "Map Download Complete"
                content.body = "The map for \(regionName.capitalized) has been downloaded successfully"
                content.sound = .default
                
                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                
                do {
                    try await UNUserNotificationCenter.current().add(request)
                } catch {
                    print("Failed to send notification: \(error)")
                }
                
                await self.loadAvailableMBTiles()
            }
        } catch {
            print("Error moving downloaded file: \(error)")
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        Task { @MainActor in
            // Stelle sicher, dass wir im Download-Status sind
            if !self.isDownloading {
                self.isPreparing = false
                self.isDownloading = true
            }
            
            self.downloadedBytes = totalBytesWritten
            self.totalBytes = totalBytesExpectedToWrite
            self.downloadProgress = Float(totalBytesWritten) / Float(totalBytesExpectedToWrite)
            
            if let startTime = self.downloadStartTime {
                let elapsedTime = Date().timeIntervalSince(startTime)
                let totalEstimatedTime = elapsedTime / Double(self.downloadProgress)
                self.estimatedTimeRemaining = totalEstimatedTime - elapsedTime
            }
        }
    }
} 