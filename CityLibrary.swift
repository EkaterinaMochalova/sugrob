import SwiftUI

struct SavedPlace: Codable, Identifiable {
    var city: WeatherCity
    var cameras: [LiveCamera]
    var id: Int { city.id }
}

enum YouTubeLink {
    static func videoID(_ text: String) -> String? {
        guard let u = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              u.scheme == "https", u.user == nil, u.password == nil, u.port == nil,
              let host = u.host?.lowercased() else { return nil }
        let parts = u.path.split(separator: "/").map(String.init)
        var id: String?
        if host == "youtu.be", parts.count == 1 { id = parts[0] }
        if ["youtube.com", "www.youtube.com", "m.youtube.com"].contains(host) {
            if u.path == "/watch" { id = u.queryItems?.first(where: { $0.name == "v" })?.value }
            else if parts.count == 2 && ["live", "embed", "shorts"].contains(parts[0]) { id = parts[1] }
        }
        guard let id, id.range(of: "^[A-Za-z0-9_-]{11}$", options: .regularExpression) != nil else { return nil }
        return id
    }
    static func camera(_ text: String, title: String, city: WeatherCity) -> LiveCamera? {
        guard let id = videoID(text) else { return nil }
        let watch = URL(string: "https://www.youtube.com/watch?v=\(id)")!
        return LiveCamera(id: "custom:\(city.id)", title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Моя камера" : String(title.prefix(120)), provider: "YouTube · добавлено вами", embed: URL(string: "https://www.youtube.com/embed/\(id)?autoplay=1&mute=1&playsinline=1"), source: watch, watch: watch)
    }
}

final class CityLibrary: ObservableObject {
    static let shared = CityLibrary()
    @Published private(set) var places: [SavedPlace] = []
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "savedPlaces"), let saved = try? JSONDecoder().decode([SavedPlace].self, from: data) {
            places = saved.filter { $0.city.latitude.isFinite && $0.city.longitude.isFinite && abs($0.city.latitude) <= 90 && abs($0.city.longitude) <= 180 }.map { place in
                SavedPlace(city: place.city, cameras: place.cameras.compactMap { YouTubeLink.camera($0.watch.absoluteString, title: $0.title, city: place.city) })
            }
        }
    }
    func save(_ city: WeatherCity, camera: LiveCamera?, replacing: String? = nil) {
        if !places.contains(where: { $0.id == city.id }) { places.append(SavedPlace(city: city, cameras: [])) }
        guard let index = places.firstIndex(where: { $0.id == city.id }) else { return }
        if let camera {
            places[index].cameras.removeAll { $0.key == camera.key || $0.key == replacing }
            places[index].cameras.append(camera)
        }
        persist()
    }
    func removeCamera(city: WeatherCity, key: String) {
        if let index = places.firstIndex(where: { $0.id == city.id }) { places[index].cameras.removeAll { $0.key == key }; persist() }
    }
    func remove(_ city: WeatherCity) { places.removeAll { $0.id == city.id }; persist() }
    private func persist() { if let data = try? JSONEncoder().encode(places) { defaults.set(data, forKey: "savedPlaces") } }
}

struct CityEditor: View {
    @ObservedObject var weather: WeatherStore
    @ObservedObject var library: CityLibrary
    @Environment(\.dismiss) private var dismiss
    @State var city: WeatherCity?
    @State private var query = ""
    @State private var link = ""
    @State private var title = ""
    @State private var replacing: String?
    @State private var preview: LiveCamera?
    @State private var message = ""
    @StateObject private var session = InlineCameraSession()
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text("Мои города и камеры").font(.title2); Spacer(); Button("Закрыть") { dismiss() } }
                HStack {
                    TextField("Найти город", text: $query).onSubmit { weather.search(query) }.onChange(of: query) { _ in weather.resetSearch() }
                    Button("Найти") { weather.search(query) }.disabled(query.count < 2 || weather.searching)
                }
                if let message = weather.searchMessage { Text(message).font(.caption) }
                ForEach(weather.results) { result in
                    Button(result.title) { city = CityPortrait.matching(result) == .neutral ? result : CityPortrait.matching(result).city; preview = nil; replacing = nil; link = ""; title = ""; weather.resetSearch() }
                }
                if let city {
                    Text(city.title).font(.headline)
                    Text("Погода и местное время определятся автоматически. Камера необязательна.").font(.caption)
                    TextField("Ссылка на YouTube: watch, live или youtu.be", text: $link).onChange(of: link) { _ in preview = nil; message = "" }
                    TextField("Название ракурса", text: $title)
                    HStack {
                        Button("Предпросмотр") {
                            preview = YouTubeLink.camera(link, title: title, city: city)
                            message = preview == nil ? "Нужна HTTPS-ссылка на конкретное видео YouTube." : ""
                        }.disabled(link.isEmpty)
                        Button(replacing == nil ? "Сохранить" : "Сохранить изменения") {
                            let camera = YouTubeLink.camera(link, title: title, city: city)
                            guard link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || camera != nil else { message = "Проверь ссылку YouTube."; return }
                            library.save(city, camera: camera, replacing: replacing)
                            weather.select(city, enableWeather: weather.enabled); dismiss()
                        }.buttonStyle(.borderedProminent)
                    }
                    Text(message).font(.caption)
                    if let preview {
                        InlineCameraView(camera: preview, session: session, expanded: false, collapse: {})
                            .frame(height: 260)
                        Text(session.status).font(.caption)
                    }
                    Text("Предпросмотр показывает доступность сейчас. Автор может запретить встраивание или завершить эфир. Обычное видео тоже можно сохранить.").font(.caption).foregroundStyle(.secondary)
                    ForEach(library.places.first(where: { $0.id == city.id })?.cameras ?? [], id: \.key) { camera in
                        HStack {
                            Text(camera.title); Spacer()
                            Button("Изменить") { link = camera.watch.absoluteString; title = camera.title; replacing = camera.key; preview = nil }
                            Button("Удалить") { library.removeCamera(city: city, key: camera.key); preview = nil; replacing = nil; link = ""; title = "" }
                        }
                    }
                    if library.places.contains(where: { $0.id == city.id }) {
                        Button("Убрать город и мои камеры из списка", role: .destructive) {
                            library.remove(city); dismiss()
                        }
                    }
                }
            }.padding(24)
        }.frame(width: 620, height: 640)
    }
}
