import Foundation

class WeatherService: ObservableObject {
    @Published var currentWeather: OpenWeatherResponse?
    @Published var error: Error?
    
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func fetchWeather(latitude: Double, longitude: Double) async {
        guard !apiKey.isEmpty else {
            error = WeatherError.noApiKey
            return
        }
        
        let urlString = "https://api.openweathermap.org/data/2.5/weather?lat=\(latitude)&lon=\(longitude)&appid=\(apiKey)&units=metric"
        
        guard let url = URL(string: urlString) else {
            error = WeatherError.invalidURL
            return
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let weather = try JSONDecoder().decode(OpenWeatherResponse.self, from: data)
            DispatchQueue.main.async {
                self.currentWeather = weather
                self.error = nil
            }
        } catch {
            DispatchQueue.main.async {
                self.error = error
            }
        }
    }
    
    enum WeatherError: LocalizedError {
        case noApiKey
        case invalidURL
        case networkError(Error)
        
        var errorDescription: String? {
            switch self {
            case .noApiKey:
                return "No API key provided. Please add your OpenWeather API key in Settings."
            case .invalidURL:
                return "Invalid URL configuration."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            }
        }
    }
} 