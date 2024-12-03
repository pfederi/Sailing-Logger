import MapKit
import SQLite3

class MBTilesOverlay: MKTileOverlay {
    private var db: OpaquePointer?
    let fileURL: URL
    private var bounds: (Double, Double, Double, Double)?

    init(fileURL: URL) {
        self.fileURL = fileURL
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
            print("❌ Database not available for: \(fileURL.lastPathComponent)")
            result(nil, NSError(domain: "MBTiles", code: 1, userInfo: nil))
            return
        }

        print("\n🗺 Tile Request for: \(fileURL.lastPathComponent)")
        print("------------------------")
        
        // Koordinatenberechnung
        let n = Double(1 << path.z)
        let lon = (Double(path.x) / n * 360.0) - 180.0
        let latRad = .pi - (2.0 * .pi * Double(path.y)) / n
        let lat = (180.0 / .pi) * atan(sinh(latRad))
        
        // Y-Koordinate für TMS
        let y = (1 << path.z) - path.y - 1
        
        print("📍 Coordinates:")
        print("   Requested: z:\(path.z) x:\(path.x) y:\(path.y)")
        print("   Transformed: z:\(path.z) x:\(path.x) y:\(y) (TMS)")
        print("   Geographic: lat:\(String(format: "%.6f", lat))° lon:\(String(format: "%.6f", lon))°")
        
        // Bounds-Check
        if let bounds = bounds {
            let isInBounds = lon >= bounds.0 && lon <= bounds.2 &&
                            lat >= bounds.1 && lat <= bounds.3
            
            print("🗺️ Bounds Check:")
            print("   Map Region: \(fileURL.lastPathComponent)")
            print("   Longitude: \(bounds.0)° to \(bounds.2)°")
            print("   Latitude: \(bounds.1)° to \(bounds.3)°")
            print("   Result: \(isInBounds ? "✅ In bounds" : "❌ Outside bounds")")
            
            if !isInBounds {
                print("⏭️ Skipping tile outside bounds")
                result(nil, nil)
                return
            }
        } else {
            print("⚠️ No bounds found in metadata")
        }
        
        let query = """
        SELECT tile_data FROM tiles 
        WHERE zoom_level = ? 
        AND tile_column = ? 
        AND tile_row = ?
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_int(statement, 1, Int32(path.z))
            sqlite3_bind_int(statement, 2, Int32(path.x))
            sqlite3_bind_int(statement, 3, Int32(y))

            if sqlite3_step(statement) == SQLITE_ROW {
                if let tileData = sqlite3_column_blob(statement, 0) {
                    let tileSize = sqlite3_column_bytes(statement, 0)
                    let data = Data(bytes: tileData, count: Int(tileSize))
                    
                    print("✅ Tile found: \(tileSize) bytes")
                    result(data, nil)
                } else {
                    print("❌ Empty tile data")
                    result(nil, nil)
                }
            } else {
                print("❌ No tile found")
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
                    
                    if nameStr == "bounds" {
                        let components = valueStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
                        if components.count == 4 {
                            bounds = (components[0], components[1], components[2], components[3])
                            print("\n🗺️ Parsed Bounds:")
                            print("   Longitude: \(components[0])° to \(components[2])°")
                            print("   Latitude:  \(components[1])° to \(components[3])°")
                        } else {
                            print("⚠️ Invalid bounds format in metadata")
                        }
                    }
                }
            }
            print("------------------------")
        }
        
        if bounds == nil {
            print("⚠️ No valid bounds found in metadata")
        }
    }
} 