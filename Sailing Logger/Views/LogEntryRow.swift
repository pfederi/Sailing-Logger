import SwiftUI
import CoreLocation

struct LogEntryRow: View {
    @ObservedObject var entry: LogEntry
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            // Motor/Segel Icon
            if entry.engineState == .on {
                Image(systemName: "engine.combustion")
                    .font(.system(size: 20))
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    .frame(width: 32)
            } else {
                Image(systemName: "sailboat")
                    .font(.system(size: 20))
                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                    .frame(width: 32)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                
                if let location = entry.locationDescription {
                    Text(location)
                        .font(.caption)
                }
                
                Text(entry.coordinates.formattedNautical())
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let maneuver = entry.maneuver {
                    Text(maneuver.rawValue)
                        .font(.body)
                }
                
                // Navigation Info
                if entry.distance > 0 || entry.magneticCourse > 0 || entry.courseOverGround > 0 || entry.speed > 0 {
                    HStack {
                        if entry.distance > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.swap")
                                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                                Text(String(format: "%.1f nm", entry.distance))
                            }
                        }
                        
                        if entry.magneticCourse > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "safari")
                                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                                Text(String(format: "%.0f°", entry.magneticCourse))
                            }
                        }
                        
                        if entry.courseOverGround > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "safari.fill")
                                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                                Text(String(format: "%.0f°", entry.courseOverGround))
                            }
                        }
                        
                        if entry.speed > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "speedometer")
                                    .foregroundColor(MaritimeColors.navy(for: colorScheme))
                                Text(String(format: "%.1f kts", entry.speed))
                            }
                        }
                    }
                    .font(.caption)
                }
                
                // Wind Info
                if entry.wind.speedKnots > 0 {
                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.left.circle")
                                .foregroundColor(MaritimeColors.navy(for: colorScheme))
                            Text(entry.wind.direction.rawValue)
                        }
                        
                        HStack(spacing: 4) {
                            Image(systemName: "wind")
                                .foregroundColor(MaritimeColors.navy(for: colorScheme))
                            Text(String(format: "%.1f kts", entry.wind.speedKnots))
                        }
                    }
                    .font(.caption)
                }
                
                // Segel als Chips - nur wenn aktiv
                if entry.sails.mainSail || entry.sails.jib || entry.sails.genoa || entry.sails.spinnaker || entry.sails.reefing > 0 {
                    HStack(spacing: 8) {
                        if entry.sails.mainSail {
                            Text("Main")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(MaritimeColors.navy(for: colorScheme).opacity(0.1))
                                .cornerRadius(8)
                        }
                        if entry.sails.jib {
                            Text("Jib")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(MaritimeColors.navy(for: colorScheme).opacity(0.1))
                                .cornerRadius(8)
                        }
                        if entry.sails.genoa {
                            Text("Genoa")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(MaritimeColors.navy(for: colorScheme).opacity(0.1))
                                .cornerRadius(8)
                        }
                        if entry.sails.spinnaker {
                            Text("Spinnaker")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(MaritimeColors.navy(for: colorScheme).opacity(0.1))
                                .cornerRadius(8)
                        }
                        if entry.sails.reefing > 0 {
                            Text("Reef \(entry.sails.reefing)")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(MaritimeColors.navy(for: colorScheme).opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .lineLimit(1)
                }
            }
        }
        .onAppear {
            Task {
                await entry.fetchLocationDescription()
            }
        }
    }
} 
