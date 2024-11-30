import SwiftUI

class ThemeManager: ObservableObject {
    @AppStorage("colorScheme") var storedColorScheme: String = "system"
    @AppStorage("openWeatherApiKey") var openWeatherApiKey: String = ""
    @AppStorage("useImperialUnits") var useImperialUnits: Bool = false
    
    var colorScheme: ColorScheme? {
        switch storedColorScheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }
    
    func updateColorScheme() {
        objectWillChange.send()
    }
} 