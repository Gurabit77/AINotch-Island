import Foundation
import Combine
import CoreLocation

enum BuddyWeather: String {
    case sunny, cloudy, rainy, snowy, stormy, hot, cold, unknown
}

@MainActor
final class WeatherService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var currentWeather: BuddyWeather = .unknown

    private var timer: AnyCancellable?
    private let locationManager = CLLocationManager()
    private var lastCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func start() {
        locationManager.startUpdatingLocation()
        timer = Timer.publish(every: 1800, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchWeather()
            }
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.fetchWeather()
        }
    }

    func stop() {
        timer?.cancel()
        timer = nil
        locationManager.stopUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.lastCoordinate = location.coordinate
        }
    }

    private func fetchWeather() {
        guard let coord = lastCoordinate else { return }
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(coord.latitude)&longitude=\(coord.longitude)&current=weather_code,temperature_2m"
        guard let url = URL(string: urlString) else { return }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let current = json["current"] as? [String: Any],
                   let code = current["weather_code"] as? Int,
                   let temp = current["temperature_2m"] as? Double {
                    await MainActor.run {
                        self.currentWeather = Self.mapWeatherCode(code, temperature: temp)
                    }
                }
            } catch {
                // Graceful fallback — keep existing weather
            }
        }
    }

    private static func mapWeatherCode(_ code: Int, temperature: Double) -> BuddyWeather {
        if temperature > 35 { return .hot }
        if temperature < 0 { return .cold }
        switch code {
        case 0, 1: return .sunny
        case 2, 3: return .cloudy
        case 51...67, 80...82: return .rainy
        case 71...77, 85, 86: return .snowy
        case 95...99: return .stormy
        default: return .cloudy
        }
    }
}
