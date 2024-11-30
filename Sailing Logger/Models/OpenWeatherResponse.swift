import Foundation

struct OpenWeatherResponse: Codable {
    let main: Main
    let wind: Wind
    let clouds: Clouds
    let visibility: Int
    
    struct Main: Codable {
        let pressure: Double
        let temp: Double
    }
    
    struct Wind: Codable {
        let speed: Double
        let deg: Double
    }
    
    struct Clouds: Codable {
        let all: Int
    }
} 