import Foundation
import SwiftUI

extension Notification.Name { static let previewAtmosphere = Notification.Name("SugrobPreviewAtmosphere") }

enum Mode: String, CaseIterable, Identifiable {
    case snow, leaves, rain, petals
    var id: String { rawValue }
    var title: String {
        switch self {
        case .snow: return "Снег"
        case .leaves: return "Осенние листья"
        case .rain: return "Дождь"
        case .petals: return "Лепестки сакуры"
        }
    }
}

struct WeatherCity: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let latitude: Double
    let longitude: Double
    var admin1: String?
    var country: String?
    var timezone: String?
    var title: String { [name, admin1, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ") }
}

struct CityResults: Decodable { var results: [WeatherCity]? }
struct WeatherResponse: Decodable { let current: CurrentWeather }
struct CurrentWeather: Decodable {
    let temperature_2m: Double
    let weather_code: Int

    var effect: Mode? {
        switch weather_code {
        case 71, 73, 75, 77, 85, 86: return .snow
        case 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 97, 99: return .rain
        default: return nil
        }
    }
    var description: String {
        switch weather_code {
        case 0, 1: return "Ясно"
        case 2, 3: return "Облачно"
        case 45, 48: return "Туман"
        case 51, 53, 55, 56, 57: return "Морось"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "Дождь"
        case 71, 73, 75, 77, 85, 86: return "Снег"
        case 95, 96, 97, 99: return "Гроза (на экране — дождь)"
        default: return "Неизвестные условия — эффект выключен"
        }
    }
}

struct WeatherAPI {
    var session: URLSession = .shared

    func request<T: Decodable>(_ endpoint: String, items: [URLQueryItem]) async throws -> T {
        var components = URLComponents(string: endpoint)!
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    func cities(_ query: String) async throws -> [WeatherCity] {
        let response: CityResults = try await request("https://geocoding-api.open-meteo.com/v1/search", items: [
            URLQueryItem(name: "name", value: query), URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: "ru"),
        ])
        return response.results ?? []
    }

    func weather(_ city: WeatherCity) async throws -> CurrentWeather {
        let response: WeatherResponse = try await request("https://api.open-meteo.com/v1/forecast", items: [
            URLQueryItem(name: "latitude", value: String(city.latitude)),
            URLQueryItem(name: "longitude", value: String(city.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
        ])
        return response.current
    }
}

@MainActor
final class WeatherStore: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var city: WeatherCity?
    @Published private(set) var current: CurrentWeather?
    @Published private(set) var updatedAt: Date?
    @Published private(set) var loading = false
    @Published private(set) var error: String?
    @Published private(set) var results: [WeatherCity] = []
    @Published private(set) var searching = false
    @Published private(set) var searchMessage: String?
    var onChange: (() -> Void)?
    private let defaults: UserDefaults
    private let api: WeatherAPI
    private var weatherTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var timer: Timer?
    private var weatherGeneration = UUID()
    private var searchGeneration = UUID()

    init(defaults: UserDefaults = .standard, api: WeatherAPI = WeatherAPI()) {
        self.defaults = defaults
        self.api = api
        let savedCity = defaults.data(forKey: "weatherCity").flatMap { try? JSONDecoder().decode(WeatherCity.self, from: $0) }
        city = savedCity
        enabled = defaults.bool(forKey: "weatherEnabled") && savedCity != nil
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        refresh()
    }

    func setEnabled(_ value: Bool) {
        enabled = value && city != nil
        defaults.set(enabled, forKey: "weatherEnabled")
        weatherTask?.cancel()
        weatherGeneration = UUID()
        loading = false
        current = nil
        updatedAt = nil
        error = nil
        onChange?()
        refresh()
    }

    func select(_ city: WeatherCity) {
        self.city = city
        defaults.set(try? JSONEncoder().encode(city), forKey: "weatherCity")
        resetSearch()
        setEnabled(true)
    }

    func resetSearch() {
        searchTask?.cancel()
        searchGeneration = UUID()
        searching = false
        results = []
        searchMessage = nil
    }

    func search(_ text: String) {
        resetSearch()
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { searchMessage = "Введите хотя бы две буквы."; return }
        searching = true
        let generation = searchGeneration
        searchTask = Task {
            do {
                let found = try await api.cities(query)
                guard !Task.isCancelled, generation == searchGeneration else { return }
                results = found
                searchMessage = found.isEmpty ? "Город не найден. Попробуйте другое название." : "Выберите город:"
            } catch {
                guard !Task.isCancelled, generation == searchGeneration else { return }
                searchMessage = "Не удалось найти город. Проверьте интернет и повторите поиск."
            }
            searching = false
        }
    }

    func refresh() {
        guard enabled, let city, !loading else { return }
        loading = true
        error = nil
        let generation = weatherGeneration
        weatherTask = Task {
            do {
                let value = try await api.weather(city)
                guard !Task.isCancelled, generation == weatherGeneration else { return }
                current = value
                updatedAt = Date()
            } catch {
                guard !Task.isCancelled, generation == weatherGeneration else { return }
                // Never present old weather as current after a failed refresh.
                current = nil
                self.error = "Не удалось обновить погоду. Реальные осадки скрыты; повторим через 15 минут."
            }
            loading = false
            onChange?()
        }
    }
}

struct WeatherSettingsView: View {
    @AppStorage("cityAtmosphere") private var atmosphere = false
    @AppStorage("atmosphereStrength") private var strength = 0.65
    @AppStorage("atmosphereSound") private var sound = false
    @AppStorage("florenceBells") private var florenceBells = false
    @AppStorage("atmosphereVolume") private var volume = 0.25
    @AppStorage("paused") private var paused = false
    @ObservedObject var weather: WeatherStore
    @State private var query = ""

    var body: some View {
        Section("Побыть в другом городе") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(CityPortrait.destinations.filter { [.moscow, .rome, .petersburg, .tokyo, .florence, .athens].contains($0) }, id: \.rawValue) { portrait in
                    Button {
                        atmosphere = true
                        weather.select(portrait.city)
                    } label: {
                        Text(portrait.city.name).frame(maxWidth: .infinity)
                    }
                }
            }
            Toggle("Включить выбранный город", isOn: Binding(
                get: { weather.enabled }, set: { weather.setEnabled($0) }
            )).disabled(weather.city == nil)
            if let city = weather.city {
                Text(city.title).font(.headline).fixedSize(horizontal: false, vertical: true)
                if CityMood(city: city).soundAsset != nil {
                Picker("Режим", selection: $atmosphere) {
                    Text("Точная погода").tag(false)
                    Text("Погода и звуки").tag(true)
                }.pickerStyle(.segmented)
                }
                if atmosphere {
                    Text("Погода выбранного города на рабочем столе.").font(.caption)
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let mood = CityMood(city: city, date: context.date)
                        Text("\(CityMood.localTime(context.date, city: city)) · \(mood.season.rawValue) · \(mood.light.rawValue)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if CityMood(city: city).soundAsset != nil {
                        Toggle("Звуковой фон", isOn: $sound)
                        if sound {
                            if CityPortrait.matching(city) == .florence {
                                Picker("Запись", selection: $florenceBells) {
                                    Text("Площадь").tag(false)
                                    Text("Колокола").tag(true)
                                }.pickerStyle(.segmented)
                            }
                            Slider(value: $volume, in: 0...1) { Text("Громкость") }
                        }
                        Text("Запись города, не прямая трансляция.").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Актуальная погода требует подключения к интернету.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            HStack {
                TextField("Название города", text: $query)
                    .onSubmit { weather.search(query) }
                    .onChange(of: query) { _ in weather.resetSearch() }
                Button("Найти") { weather.search(query) }
                    .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || weather.searching)
            }
            if weather.searching { Text("Ищем город…").foregroundStyle(.secondary) }
            if let message = weather.searchMessage { Text(message).font(.caption) }
            ForEach(weather.results) { city in
                Button { weather.select(city) } label: {
                    Text(city.title).frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if weather.enabled {
                if let current = weather.current {
                    Text("\(current.description), \(current.temperature_2m, specifier: "%.0f") °C")
                    if current.effect == nil { Text("Осадков на экране нет.").font(.caption) }
                }
                if let date = weather.updatedAt {
                    Text("Последнее обновление: \(date.formatted(date: .omitted, time: .shortened))").font(.caption)
                }
                if let error = weather.error { Text(error).foregroundStyle(.red).font(.caption) }
                Button(weather.loading ? "Обновляем…" : "Обновить погоду") { weather.refresh() }
                    .disabled(weather.loading)
            }
            Text("Снег и дождь повторяют погоду города, обновление каждые 15 минут. В «Точной погоде» без осадков экран чистый. Выключите город, чтобы вернуть ручной эффект.")
                .font(.caption).foregroundStyle(.secondary)
            Link("Данные погоды: Open-Meteo · Города: GeoNames", destination: URL(string: "https://open-meteo.com/")!)
                .font(.caption)
        }
    }
}
