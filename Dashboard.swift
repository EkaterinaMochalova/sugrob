import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case sage, sand, blue, lavender
    var id: String { rawValue }
    var title: String { switch self {
    case .sage: return "Шалфей"
    case .sand: return "Песок"
    case .blue: return "Голубая"
    case .lavender: return "Лаванда"
    } }
    private var rgb: (UInt32, UInt32, UInt32) { switch self {
    case .sage: return (0xF5F3E9, 0xE5EADD, 0x263B32)
    case .sand: return (0xFAF3E9, 0xEEDFCB, 0x594333)
    case .blue: return (0xEFF4F8, 0xDBE7F0, 0x293F56)
    case .lavender: return (0xF5F0F8, 0xE8DFF0, 0x493855)
    } }
    private func color(_ n: UInt32) -> Color { Color(red: Double((n >> 16) & 255)/255, green: Double((n >> 8) & 255)/255, blue: Double(n & 255)/255) }
    var paper: Color { color(rgb.0) }
    var sidebar: Color { color(rgb.1) }
    var ink: Color { color(rgb.2) }
}
private let destinations: [CityPortrait] = [.florence, .rome, .tokyo, .petersburg, .moscow, .athens, .nizhny, .newyork]

struct DashboardView: View {
    @ObservedObject var weather: WeatherStore
    @AppStorage("appTheme") private var theme = AppTheme.sage
    private var ink: Color { theme.ink }
    private var paper: Color { theme.paper }
    @State private var settings = false
    @State private var query = ""
    @State private var cameraChoice = ""
    @State private var expanded = false
    @AppStorage("cameraCollapsed") private var cameraCollapsed = false
    @StateObject private var cameraSession = InlineCameraSession()
    @AppStorage("mode") private var manualMode = Mode.snow
    @AppStorage("intensity") private var intensity = 1.0
    @AppStorage("speed") private var speed = 1.0
    @AppStorage("cityAtmosphere") private var atmosphere = false
    @AppStorage("atmosphereSound") private var sound = false
    @AppStorage("florenceBells") private var bells = false
    @AppStorage("atmosphereVolume") private var volume = 0.25
    @AppStorage("paused") private var paused = false

    var body: some View {
        GeometryReader { geometry in
        HStack(spacing: 0) {
            if !expanded {
            VStack(alignment: .leading, spacing: 24) {
                Label("сугроб", systemImage: "snowflake").font(.system(size: 24, weight: .semibold, design: .serif))
                    .padding(.top, 10)
                Text("ГДЕ ПОБУДЕМ?").font(.system(size: 10, weight: .semibold)).tracking(2).opacity(0.55)
                ScrollView {
                VStack(spacing: 8) {
                    ForEach(destinations, id: \.rawValue) { portrait in
                        Button {
                            atmosphere = true; weather.select(portrait.city, enableWeather: weather.enabled); settings = false
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
                }
                Spacer(minLength: 0)
                Button { settings.toggle() } label: {
                    Label(settings ? "Вернуться к городу" : "Эффекты и настройки", systemImage: settings ? "arrow.left" : "slider.horizontal.3")
                }.buttonStyle(.plain).font(.system(size: 12))
                Text("Немного ближе\nк другому месту.").font(.system(size: 13, design: .serif)).opacity(0.55).lineSpacing(4)
            }.padding(24).frame(width: 230).background(theme.sidebar)
            }
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
                            cameraCard(city, height: expanded ? max(360, geometry.size.height - 228) : max(180, min(260, geometry.size.height * 0.30)))
                        } else {
                            Text("Побудем\nгде-нибудь ещё.").font(.system(size: 42, weight: .regular, design: .serif))
                            Text("Выбери город слева — его погода, звуки и вид из окна будут рядом.").font(.system(size: 15)).foregroundStyle(.secondary)
                        }
                        if !expanded {
                        weatherSource
                        if let city = weather.city {
                            if weather.enabled { weatherCard(city) }
                            if CityMood(city: city).soundAsset != nil { soundCard(city) }
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
                                    Button(city.title) { weather.select(city, enableWeather: weather.enabled) }.buttonStyle(.link)
                                }
                                Text("Для найденного города доступна погода. Камеры есть у городов в списке слева.").font(.caption).foregroundStyle(.secondary)
                            }.padding(.top, 8)
                        }.font(.system(size: 12))
                        Link("Погода: Open-Meteo · Города: GeoNames", destination: URL(string: "https://open-meteo.com/")!).font(.system(size: 10)).opacity(0.6)
                        }
                    }.padding(24)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(ink).tint(ink).background(paper).preferredColorScheme(.light)
        }
        .frame(minWidth: 850, idealWidth: 1040, minHeight: 680, idealHeight: 820)
        .onExitCommand { expanded = false }
    }
    private var weatherSource: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Что показывать на экране").font(.system(size: 15, weight: .medium))
            Picker("Источник погоды", selection: Binding(get: { weather.enabled }, set: { weather.setEnabled($0) })) {
                Text("Погода города").tag(true).disabled(weather.city == nil)
                Text("Своя погода").tag(false)
            }.pickerStyle(.segmented)
            if !weather.enabled {
                Picker("Мой эффект", selection: $manualMode) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.menu)
                Text("Эффект выбран вручную. Камеры можно смотреть независимо от него.").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Осадки определяются погодой выбранного города.").font(.caption).foregroundStyle(.secondary)
            }
            HStack { Text("Количество").font(.caption).frame(width: 80, alignment: .leading); Slider(value: $intensity, in: 0.1...3) }
            HStack { Text("Скорость").font(.caption).frame(width: 80, alignment: .leading); Slider(value: $speed, in: 0.3...2.5) }
        }.padding(20).background(Color.white.opacity(0.7)).cornerRadius(16)
    }
    private func cityHeader(_ city: WeatherCity) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(city.name).font(.system(size: 34, weight: .regular, design: .serif))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Text(CityMood.localTime(context.date, city: city)).font(.system(size: 26, weight: .light)).monospacedDigit()
                if let current = weather.current, weather.enabled {
                    Text("\(Int(current.temperature_2m.rounded()))°").font(.system(size: 24, weight: .light))
                }
            }
        }
    }
    private func cameraCard(_ city: WeatherCity, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            let choices = LiveCamera.forCity(city)
            if let camera = choices.first(where: { $0.key == cameraChoice }) ?? choices.first {
                HStack {
                    if choices.count > 1 {
                        Picker("Ракурс", selection: Binding(get: { camera.key }, set: { cameraChoice = $0 })) {
                            ForEach(choices, id: \.key) { Text($0.title).tag($0.key) }
                        }.labelsHidden()
                    } else { Text(camera.title).font(.system(size: 14)) }
                    Spacer()
                    Button(cameraCollapsed ? "Показать видео" : "Свернуть видео") {
                        expanded = false
                        cameraCollapsed.toggle()
                    }.buttonStyle(.borderless).font(.system(size: 11))
                    Button { cameraCollapsed = false; expanded.toggle() } label: {
                        Image(systemName: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }.help(expanded ? "Вернуться · Esc" : "Развернуть вид")
                }
                if !cameraCollapsed {
                InlineCameraView(camera: camera, session: cameraSession, expanded: expanded, collapse: { expanded = false })
                    .frame(height: height).clipShape(RoundedRectangle(cornerRadius: 14))
                HStack {
                    Text(cameraSession.status).font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Link(camera.provider, destination: camera.source).font(.system(size: 10))
                    Button("Обновить") { cameraSession.reload() }.font(.system(size: 11)).buttonStyle(.borderless)
                }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "window.ceiling").font(.system(size: 30, weight: .light))
                    Text("Здесь пока нет live-камеры").font(.system(size: 24, design: .serif))
                    Text("Погода города доступна ниже.").font(.caption)
                }.frame(maxWidth: .infinity, minHeight: 230, alignment: .center)
            }
        }.padding(14).background(Color.white.opacity(0.7)).cornerRadius(18)
    }
    private func weatherCard(_ city: WeatherCity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Погода на рабочем столе", systemImage: "cloud.rain").font(.system(size: 14, weight: .medium))
                Spacer()
                Text(weather.enabled ? "АВТО" : "ВЫКЛ").font(.system(size: 10, weight: .semibold))
            }
            Text(city.id == -2 ? "Open-Meteo · район Ватикана" : "Open-Meteo · погода в районе города").font(.caption).foregroundStyle(.secondary)
            if let current = weather.current {
                Text("\(Int(current.temperature_2m.rounded()))° · \(current.description)").font(.system(size: 22, weight: .light))
                if current.effect == nil { Text(current.precipitationNote).font(.caption).foregroundStyle(.secondary) }
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
                    .onChange(of: sound) { on in if on { atmosphere = true } }
            }
            if sound {
                if CityPortrait.matching(city) == .florence {
                    Picker("Запись", selection: $bells) { Text("Площадь").tag(false); Text("Колокола").tag(true) }.pickerStyle(.segmented)
                }
                Slider(value: $volume, in: 0...1) { Text("Громкость") }
                if paused { Text("Звук приостановлен вместе с эффектами города.").font(.caption) }
            }
            Text("Полевая запись · отдельно от звука live-камеры").font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(20).background(Color.white.opacity(0.7)).cornerRadius(16)
    }
}
