import Foundation
import Combine

@MainActor
final class BuddyEnvironmentService: ObservableObject {
    @Published private(set) var weatherScene: CrabScene?

    private let weatherService = WeatherService()
    private let systemLoadMonitor = SystemLoadMonitor()
    private var cancellables = Set<AnyCancellable>()

    weak var emotionState: BuddyEmotionState?

    func start() {
        weatherService.start()
        systemLoadMonitor.start()

        weatherService.$currentWeather
            .removeDuplicates()
            .sink { [weak self] weather in
                self?.updateWeatherScene(weather)
            }
            .store(in: &cancellables)

        systemLoadMonitor.$isHighLoad
            .removeDuplicates()
            .sink { [weak self] isHigh in
                if isHigh {
                    self?.emotionState?.energy = max(0, (self?.emotionState?.energy ?? 50) - 2)
                }
            }
            .store(in: &cancellables)
    }

    func stop() {
        weatherService.stop()
        systemLoadMonitor.stop()
        cancellables.removeAll()
    }

    private func updateWeatherScene(_ weather: BuddyWeather) {
        switch weather {
        case .rainy, .stormy:
            weatherScene = .weatherRainy
        case .cold, .snowy:
            weatherScene = .weatherCold
        case .hot:
            weatherScene = .weatherHot
        default:
            weatherScene = nil
        }
    }
}
