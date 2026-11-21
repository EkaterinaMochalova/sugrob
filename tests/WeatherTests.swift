import Foundation

final class StubProtocol: URLProtocol {
    static var handler: (URLRequest) -> (Int, String) = { _ in (500, "{}") }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, body) = Self.handler(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status,
                         httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@main struct WeatherTests {
    @MainActor static func waitFor(_ condition: () -> Bool) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        fatalError("Timed out")
    }

    @MainActor static func main() async throws {
        try checkAtmosphere()
        for code in [71, 73, 75, 77, 85, 86] {
            precondition(CurrentWeather(temperature_2m: -2, weather_code: code).effect == .snow)
        }
        for code in [51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 97, 99] {
            precondition(CurrentWeather(temperature_2m: 10, weather_code: code).effect == .rain)
        }
        for code in [0, 1, 2, 3, 45, 48, 999] {
            precondition(CurrentWeather(temperature_2m: 10, weather_code: code).effect == nil)
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        let api = WeatherAPI(session: URLSession(configuration: config))
        StubProtocol.handler = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            precondition(query.first { $0.name == "name" }?.value == "Нижний Новгород")
            return (200, #"{"results":[{"id":1,"name":"Нижний Новгород","latitude":56.3,"longitude":44.0}]}"#)
        }
        let cities = try await api.cities("Нижний Новгород")
        precondition(cities.count == 1 && cities[0].title == "Нижний Новгород")
        StubProtocol.handler = { _ in (200, "{}") }
        let empty = try await api.cities("Unknown")
        precondition(empty.isEmpty)
        StubProtocol.handler = { _ in (503, "{}") }
        do { _ = try await api.weather(cities[0]); fatalError("HTTP error accepted") } catch {}
        StubProtocol.handler = { _ in (200, #"{"current":{"weather_code":71}}"#) }
        do { _ = try await api.weather(cities[0]); fatalError("Malformed weather accepted") } catch {}

        let suite = "SugrobWeatherTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("petals", forKey: "mode")
        let store = WeatherStore(defaults: defaults, api: api)
        precondition(!store.enabled && store.city == nil)
        store.setEnabled(true)
        precondition(!store.enabled)
        StubProtocol.handler = { _ in (200, #"{"current":{"temperature_2m":-3,"weather_code":71}}"#) }
        store.select(cities[0])
        await waitFor { !store.loading }
        precondition(store.enabled && store.current?.effect == .snow)
        let restored = WeatherStore(defaults: defaults, api: api)
        precondition(restored.enabled && restored.city == cities[0] && restored.current == nil)

        StubProtocol.handler = { _ in (503, "{}") }
        store.refresh()
        await waitFor { !store.loading }
        precondition(store.error != nil && store.current == nil)
        StubProtocol.handler = { _ in (200, #"{"current":{"temperature_2m":20,"weather_code":0}}"#) }
        store.refresh()
        await waitFor { !store.loading }
        precondition(store.error == nil && store.current != nil && store.current?.effect == nil)

        // A cancelled request must not turn weather back on or replace the next city.
        store.refresh()
        store.setEnabled(false)
        try await Task.sleep(nanoseconds: 50_000_000)
        precondition(!store.enabled && store.current == nil && !store.loading)
        precondition(defaults.string(forKey: "mode") == "petals")
        let second = WeatherCity(id: 2, name: "Paris", latitude: 48.85, longitude: 2.35)
        StubProtocol.handler = { request in
            let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!.queryItems!
            let code = query.first { $0.name == "latitude" }?.value == "48.85" ? 61 : 71
            return (200, "{\"current\":{\"temperature_2m\":5,\"weather_code\":\(code)}}")
        }
        store.select(cities[0])
        store.select(second)
        await waitFor { !store.loading }
        precondition(store.city == second && store.current?.effect == .rain)
        store.search("Paris")
        store.resetSearch()
        try await Task.sleep(nanoseconds: 50_000_000)
        precondition(store.results.isEmpty && !store.searching && store.searchMessage == nil)
        print("PASS: WMO codes, geocoding, HTTP/JSON errors, persistence, recovery, cancellation, city switching, manual settings")
    }
}
