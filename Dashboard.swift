import SwiftUI

private let ink = Color(red: 0.15, green: 0.23, blue: 0.20)
private let paper = Color(red: 0.96, green: 0.95, blue: 0.91)
private let destinations: [CityPortrait] = [.florence, .rome, .tokyo, .petersburg, .moscow, .athens]

struct DashboardView: View {
    @ObservedObject var weather: WeatherStore
    @State private var settings = false
    @State private var query = ""
    @AppStorage("cityAtmosphere") private var atmosphere = false
    @AppStorage("atmosphereSound") private var sound = false
    @AppStorage("florenceBells") private var bells = false
    @AppStorage("atmosphereVolume") private var volume = 0.25
    @AppStorage("paused") private var paused = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                Label("сугроб", systemImage: "snowflake").font(.system(size: 24, weight: .semibold, design: .serif))
                    .padding(.top, 10)
                Text("ГДЕ ПОБУДЕМ?").font(.system(size: 10, weight: .semibold)).tracking(2).opacity(0.55)
                VStack(spacing: 8) {
                    ForEach(destinations, id: \.rawValue) { portrait in
                        Button {
                            atmosphere = true; weather.select(portrait.city); settings = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(portrait.city.name).font(.system(size: 14, weight: .medium))
                                    Text(portrait.city.country ?? "").font(.system(size: 11)).opacity(0.6)
                                }
                                Spacer()
                                if weather.city.map({ CityPortrait.matching($0) }) == portrait {
                                    Circle().fill(ink).frame(width: 6, height: 6)
                                }
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(weather.city.map({ CityPortrait.matching($0) }) == portrait ? Color.white.opacity(0.85) : .clear)
                                .cornerRadius(12)
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
                Button { settings.toggle() } label: {
                    Label(settings ? "Вернуться к городу" : "Эффекты и настройки", systemImage: settings ? "arrow.left" : "slider.horizontal.3")
                }.buttonStyle(.plain).font(.system(size: 12))
                Text("Немного ближе\nк другому месту.").font(.system(size: 13, design: .serif)).opacity(0.55).lineSpacing(4)
            }.padding(24).frame(width: 230).background(Color(red: 0.90, green: 0.92, blue: 0.87))
            if settings {
                SettingsView(weather: weather).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            Text("ОКНО В ДРУГОЙ ГОРОД").font(.system(size: 10, weight: .semibold)).tracking(2).opacity(0.55)
                            Spacer()
                            Button { paused.toggle() } label: { Label(paused ? "Продолжить эффекты" : "Пауза эффектов", systemImage: paused ? "play" : "pause") }
                                .buttonStyle(.borderless).font(.system(size: 11))
                        }
                        if let city = weather.city {
                            cityHeader(city)
                            cameraCard(city)
                            weatherCard(city)
                            if CityMood(city: city).soundAsset != nil { soundCard(city) }
                        } else {
                            Text("Побудем\nгде-нибудь ещё.").font(.system(size: 42, weight: .regular, design: .serif))
                            Text("Выбери город слева — его погода, звуки и вид из окна будут рядом.").font(.system(size: 15)).foregroundStyle(.secondary)
                        }
                        DisclosureGroup("Другой город") {
                            VStack(alignment: .leading) {
                                HStack {
                                    TextField("Название города", text: $query).textFieldStyle(.roundedBorder)
                                        .onSubmit { weather.search(query) }.onChange(of: query) { _ in weather.resetSearch() }
                                    Button("Найти") { weather.search(query) }.disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || weather.searching)
                                }
                                if let message = weather.searchMessage { Text(message).font(.caption) }
                                ForEach(weather.results) { city in
                                    Button(city.title) { weather.select(city) }.buttonStyle(.link)
                                }
                                Text("Для найденного города доступна погода. Камеры есть у городов в списке слева.").font(.caption).foregroundStyle(.secondary)
                            }.padding(.top, 8)
                        }.font(.system(size: 12))
                        Link("Погода: Open-Meteo · Города: GeoNames", destination: URL(string: "https://open-meteo.com/")!).font(.system(size: 10)).opacity(0.6)
                    }.padding(32)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(ink).tint(ink).background(paper).preferredColorScheme(.light)
        .frame(minWidth: 850, idealWidth: 900, minHeight: 680, idealHeight: 760)
    }
    private func cityHeader(_ city: WeatherCity) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            VStack(alignment: .leading, spacing: 12) {
                Text(city.name).font(.system(size: city.name.count > 12 ? 36 : 48, weight: .regular, design: .serif))
                    .lineLimit(1).minimumScaleFactor(0.7)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(CityMood.localTime(context.date, city: city)).font(.system(size: 38, weight: .ultraLight)).monospacedDigit()
                    Text("\(city.country ?? "") · \(CityMood(city: city, date: context.date).season.rawValue)")
                        .font(.system(size: 12)).opacity(0.6)
                }
            }
        }
    }
    private func cameraCard(_ city: WeatherCity) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let camera = LiveCamera.forCity(city) {
                HStack {
                    Image(systemName: "video").font(.system(size: 24, weight: .light))
                    Spacer()
                    Text(camera.embed == nil ? "НА САЙТЕ КАМЕРЫ" : "LIVE-КАМЕРА").font(.system(size: 9, weight: .semibold)).tracking(1.5)
                }
                Text(camera.title).font(.system(size: 23, design: .serif))
                Text(camera.provider).font(.system(size: 11)).opacity(0.65)
                Button {
                    NotificationCenter.default.post(name: .openLiveCamera, object: camera)
                } label: {
                    HStack { Text(camera.embed == nil ? "Смотреть в браузере" : "Открыть окно"); Spacer(); Image(systemName: "arrow.up.right") }
                        .padding(12).background(paper).foregroundStyle(ink).cornerRadius(9)
                }.buttonStyle(.plain)
                Text(camera.embed == nil ? "Для этой камеры доступен просмотр на сайте владельца." : "Настоящий свет и время города. Звук включается в плеере.")
                    .font(.system(size: 11)).opacity(0.65)
            } else { Text("Для этого города камера пока не добавлена.") }
        }.padding(22).frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(paper).background(ink).cornerRadius(18)
    }
    private func weatherCard(_ city: WeatherCity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Погода на рабочем столе", systemImage: "cloud.rain").font(.system(size: 14, weight: .medium))
                Spacer()
                Toggle("Погода города", isOn: Binding(get: { weather.enabled }, set: { weather.setEnabled($0) })).labelsHidden().toggleStyle(.switch)
            }
            if let current = weather.current {
                Text("\(Int(current.temperature_2m.rounded()))° · \(current.description)").font(.system(size: 22, weight: .light))
                if current.effect == nil { Text("Сейчас без осадков — экран остаётся чистым.").font(.caption).foregroundStyle(.secondary) }
            } else { Text(weather.loading ? "Узнаём погоду…" : weather.enabled ? "Погода пока недоступна." : "Включи погоду города, чтобы обновить данные.").font(.caption) }
            if let error = weather.error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                if let date = weather.updatedAt { Text("Обновлено \(date.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary) }
                Spacer()
                Button("Обновить") { weather.refresh() }.disabled(weather.loading || !weather.enabled).buttonStyle(.borderless).font(.caption)
            }
            if !weather.enabled { Text("Включён ручной эффект. Его можно изменить в настройках.").font(.caption).foregroundStyle(.secondary) }
        }.padding(20).background(Color.white.opacity(0.7)).cornerRadius(16)
    }
    private func soundCard(_ city: WeatherCity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Звуки города", systemImage: "waveform").font(.system(size: 14, weight: .medium))
                Spacer()
                Toggle("Звуки города", isOn: $sound).labelsHidden().toggleStyle(.switch)
                    .onChange(of: sound) { on in if on { atmosphere = true; weather.setEnabled(true) } }
            }
            if sound {
                if CityPortrait.matching(city) == .florence {
                    Picker("Запись", selection: $bells) { Text("Площадь").tag(false); Text("Колокола").tag(true) }.pickerStyle(.segmented)
                }
                Slider(value: $volume, in: 0...1) { Text("Громкость") }
                if paused || !weather.enabled { Text("Звук приостановлен вместе с эффектами города.").font(.caption) }
            }
            Text("Полевая запись · отдельно от звука live-камеры").font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(20).background(Color.white.opacity(0.7)).cornerRadius(16)
    }
}
