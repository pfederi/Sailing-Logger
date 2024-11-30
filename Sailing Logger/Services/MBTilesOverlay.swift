import MapKit
import SQLite3

class MBTilesOverlay: MKTileOverlay {
    private var db: OpaquePointer?

    init(fileURL: URL) {
        super.init(urlTemplate: nil)
        print("\n🚀 Initializing MBTilesOverlay")
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("❌ Failed to open database at: \(fileURL.path)")
            print("💡 Error: \(String(cString: sqlite3_errmsg(db)))")
        } else {
            print("✅ Successfully opened MBTiles database at: \(fileURL.path)")
            checkMetadata()
            checkTileCounts()
        }
    }

    deinit {
        sqlite3_close(db)
    }

    private func checkTileCounts() {
        guard let db = db else { return }
        
        let query = """
            SELECT zoom_level, COUNT(*) as count 
            FROM tiles 
            GROUP BY zoom_level 
            ORDER BY zoom_level
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            print("\n📊 Tile Statistics:")
            while sqlite3_step(statement) == SQLITE_ROW {
                let zoom = sqlite3_column_int(statement, 0)
                let count = sqlite3_column_int(statement, 1)
                print("   Zoom Level \(zoom): \(count) tiles")
            }
            print("------------------------")
        }
        sqlite3_finalize(statement)
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        guard let db = db else {
            print("❌ Database not available")
            result(nil, NSError(domain: "MBTiles", code: 1, userInfo: nil))
            return
        }

        // Bounds für channel.mbtiles (nautische Koordinaten)
        let bounds = (-11.25, 40.97989806962013, 11.25, 55.77657301866769)
        
        // Berechne die nautischen Koordinaten für die angeforderte Tile
        let n = Double(1 << path.z)
        // Nautische Längengrad-Berechnung
        let lon = (Double(path.x) / n * 360.0) - 180.0
        // Nautische Breitengrad-Berechnung (Mercator)
        let latRad = .pi - (2.0 * .pi * Double(path.y)) / n
        let lat = (180.0 / .pi) * atan(sinh(latRad))
        
        print("\n🌍 Tile Coordinates:")
        print("   Tile: z:\(path.z) x:\(path.x) y:\(path.y)")
        print("   Nautical: lat:\(lat)° lon:\(lon)°")
        print("   Bounds: lon:(\(bounds.0)° to \(bounds.2)°) lat:(\(bounds.1)° to \(bounds.3)°)")
        
        let query = """
        SELECT tile_data FROM tiles WHERE zoom_level = ? AND tile_column = ? AND tile_row = ?
        """
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            // TMS y-Koordinate für nautische Karten
            let tmsY = (1 << path.z) - path.y - 1
            
            print("🔍 Database Query:")
            print("   z: \(path.z), x: \(path.x), y: \(tmsY)")
            print("   Original y: \(path.y)")
            print("   TMS y: \(tmsY)")
            
            sqlite3_bind_int(statement, 1, Int32(path.z))
            sqlite3_bind_int(statement, 2, Int32(path.x))
            sqlite3_bind_int(statement, 3, Int32(tmsY))

            if sqlite3_step(statement) == SQLITE_ROW {
                if let tileData = sqlite3_column_blob(statement, 0) {
                    let tileSize = sqlite3_column_bytes(statement, 0)
                    let data = Data(bytes: tileData, count: Int(tileSize))
                    print("✅ Found tile (\(tileSize) bytes)")
                    result(data, nil)
                } else {
                    print("❌ No tile data in blob")
                    result(nil, nil)
                }
            } else {
                print("❌ No matching tile")
                result(nil, nil)
            }
        }
        sqlite3_finalize(statement)
    }

    private func checkMetadata() {
        guard let db = db else { return }
        
        let query = "SELECT name, value FROM metadata"
        var statement: OpaquePointer?
        
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            print("\n📝 MBTiles Metadata:")
            while sqlite3_step(statement) == SQLITE_ROW {
                if let name = sqlite3_column_text(statement, 0),
                   let value = sqlite3_column_text(statement, 1) {
                    let nameStr = String(cString: name)
                    let valueStr = String(cString: value)
                    print("   \(nameStr): \(valueStr)")
                }
            }
            print("------------------------")
        }
        sqlite3_finalize(statement)
    }
} 