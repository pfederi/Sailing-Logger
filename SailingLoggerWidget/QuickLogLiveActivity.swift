import WidgetKit
import SwiftUI
import ActivityKit
import SailingLoggerShared

struct QuickLogLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuickLogAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.coordinates.formattedNautical())
                            .font(.caption2)
                    } icon: {
                        Image(systemName: "location.fill")
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Button(action: {
                        quickLogCurrentPosition(
                            coordinates: context.state.coordinates,
                            speed: context.state.speed,
                            course: context.state.course
                        )
                    }) {
                        Label("Log", systemImage: "plus.circle.fill")
                    }
                }
            } compactLeading: {
                Label {
                    Text("Log")
                } icon: {
                    Image(systemName: "plus.circle.fill")
                }
            } compactTrailing: {
                Image(systemName: "location.fill")
            } minimal: {
                Image(systemName: "plus.circle.fill")
            }
        }
    }
}

struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<QuickLogAttributes>
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "location.fill")
                Text(context.state.coordinates.formattedNautical())
                    .font(.caption)
                Spacer()
                Button {
                    quickLogCurrentPosition(
                        coordinates: context.state.coordinates,
                        speed: context.state.speed,
                        course: context.state.course
                    )
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                }
            }
            .padding(.horizontal)
            
            if context.state.speed != nil || context.state.course != nil {
                HStack {
                    if let speed = context.state.speed {
                        Label {
                            Text(String(format: "%.1f kts", speed))
                        } icon: {
                            Image(systemName: "speedometer")
                        }
                    }
                    if let course = context.state.course {
                        Label {
                            Text(String(format: "%.0f°", course))
                        } icon: {
                            Image(systemName: "safari")
                        }
                    }
                }
                .font(.caption)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }
}

// Helper function für Quick Logging
private func quickLogCurrentPosition(coordinates: Coordinates, speed: Double?, course: Double?) {
    let entry = QuickLogEntry(
        coordinates: coordinates,
        speed: speed ?? 0,
        courseOverGround: course ?? 0
    )
    
    // Sende den Log-Eintrag an die App
    Task {
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("QuickLogEntry"),
                object: nil,
                userInfo: ["entry": entry]
            )
        }
    }
} 