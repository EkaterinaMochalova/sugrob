import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case sand, sage, redleaf, blue, rocks, clouds
    var id: String { rawValue }
    var title: String { switch self {
    case .sage: return "Лист"
    case .redleaf: return "Л̶и̶с̶т̶"
    case .sand: return "Песок"
    case .blue: return "Туман"
    case .rocks: return "Скалы"
    case .clouds: return "Облака"
    } }
    private var rgb: (UInt32, UInt32, UInt32) { switch self {
    case .sage: return (0xF5F3E9, 0xE5EADD, 0x263B32)
    case .redleaf: return (0xF0EEEE, 0xDCD7D7, 0x862F3C)
    case .sand: return (0xFAF3E9, 0xEEDFCB, 0x594333)
    case .blue: return (0xEFF2F1, 0xDDE4E2, 0x394C48)
    case .rocks: return (0xE8E7E5, 0xCECDCA, 0x383B40)
    case .clouds: return (0xF5F8FC, 0xE4ECF7, 0x344B66)
    } }
    private func color(_ n: UInt32) -> Color { Color(red: Double((n >> 16) & 255)/255, green: Double((n >> 8) & 255)/255, blue: Double(n & 255)/255) }
    var paper: Color { color(rgb.0) }
    var sidebar: Color { color(rgb.1) }
    var ink: Color { color(rgb.2) }
}
private let destinations: [CityPortrait] = [.florence, .rome, .tokyo, .petersburg, .moscow, .athens, .nizhny, .newyork, .yerevan]

struct DashboardView: View {
    @ObservedObject var weather: WeatherStore
    var onCompactChange: (Bool) -> Void = { _ in }
    @State private var compact = false
    @State private var hovering = false
    @AppStorage("appTheme") private var theme = AppTheme.sage
    private var ink: Color { theme.ink }
    private var paper: Color { theme.paper }
    @State private var settings = false
    @ObservedObject private var library = CityLibrary.shared
    @State private var editingCity = false
    @State private var editorCity: WeatherCity?
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
            if !expanded && !compact {
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
                ForEach(library.places.filter { CityPortrait.matching($0.city) == .neutral }) { place in
                    Button(place.city.title) { weather.select(place.city, enableWeather: weather.enabled); settings = false }
                        .buttonStyle(.plain).font(.system(size: 12))
                }
                }
                Button("＋ Добавить город") { editorCity = nil; editingCity = true }
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
                    VStack(alignment: .leading, spacing: compact ? 8 : 22) {
                        if !compact {
                        HStack {
                            Text("ОКНО В ДРУГОЙ ГОРОД").font(.system(size: 10, weight: .semibold)).tracking(2).opacity(0.55)
                            Spacer()
                            Button("Окно") { enterCompact() }.help("Компактный вид рядом с работой")
                                .disabled(weather.city == nil)
                            Button { paused.toggle() } label: { Label(paused ? "Продолжить эффекты" : "Пауза эффектов", systemImage: paused ? "play" : "pause") }
                                .buttonStyle(.borderless).font(.system(size: 11))
                        }
                        }
                        if let city = weather.city {
                            if compact { compactHeader(city) } else { cityHeader(city) }
                            cameraCard(city, height: compact ? max(150, geometry.size.height - 160) : expanded ? max(360, geometry.size.height - 228) : max(180, min(260, geometry.size.height * 0.30)))
                        } else {
                            Text("Побудем\nгде-нибудь ещё.").font(.system(size: 42, weight: .regular, design: .serif))
                            Text("Выбери город слева — его погода, звуки и вид из окна будут рядом.").font(.system(size: 15)).foregroundStyle(.secondary)
                        }
                        if !expanded && !compact {
                        weatherSource
                        if let city = weather.city {
                            if weather.enabled { weatherCard(city) }

                        }
                        SoundControls(weather: weather).padding(20).background(Color.white.opacity(0.7)).cornerRadius(16)
                        DisclosureGroup("Другой город") {
                            VStack(alignment: .leading) {
                                HStack {
                                    TextField("Название города", text: $query).textFieldStyle(.roundedBorder)
                                        .onSubmit { weather.search(query) }.onChange(of: query) { _ in weather.resetSearch() }
                                    Button("Найти") { weather.search(query) }.disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 || weather.searching)
                                }
                                if let message = weather.searchMessage { Text(message).font(.caption) }
                                ForEach(weather.results) { city in
                                    Button(city.title) { editorCity = CityPortrait.matching(city) == .neutral ? city : CityPortrait.matching(city).city; editingCity = true }.buttonStyle(.link)
                                }
                                Text("Город и свои YouTube-камеры можно сохранить через «Мои камеры».").font(.caption).foregroundStyle(.secondary)
                            }.padding(.top, 8)
                        }.font(.system(size: 12))
                        Link("Погода: Open-Meteo · Города: GeoNames", destination: URL(string: "https://open-meteo.com/")!).font(.system(size: 10)).opacity(0.6)
                        }
                    }.padding(compact ? 12 : 24)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .foregroundStyle(ink).tint(ink).background(paper).preferredColorScheme(.light)
        }
        .frame(minWidth: compact ? 360 : 850, idealWidth: compact ? 520 : 1040, minHeight: compact ? 300 : 680, idealHeight: compact ? 430 : 820)
        .onHover { hovering = $0 }
        .onChange(of: compact) { value in DispatchQueue.main.async { onCompactChange(value) } }
        .onExitCommand { if compact { compact = false }; expanded = false }
        .sheet(isPresented: $editingCity) { CityEditor(weather: weather, library: library, city: editorCity) }
    }
    private func enterCompact() { settings = false; expanded = false; cameraCollapsed = false; compact = true }
    private func compactHeader(_ city: WeatherCity) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Menu {
                    ForEach(destinations, id: \.rawValue) { portrait in
                        Button(portrait.city.name) { weather.select(portrait.city, enableWeather: weather.enabled) }
                    }
                    ForEach(library.places.filter { CityPortrait.matching($0.city) == .neutral }) { place in
                        Button(place.city.name) { weather.select(place.city, enableWeather: weather.enabled) }
                    }
                } label: { Text(city.name).font(.system(size: 21, design: .serif)).lineLimit(1).minimumScaleFactor(0.65) }
                .menuStyle(.borderlessButton)
                Spacer()
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    Text(CityMood.localTime(context.date, city: city)).monospacedDigit()
                }
                Button { compact = false } label: { Image(systemName: "arrow.up.left.and.arrow.down.right") }
                    .help("Вернуться к полному виду · Esc").accessibilityLabel("Вернуться к полному виду")
            }
            HStack {
                if let current = weather.current, weather.enabled {
                    Text("\(Int(current.temperature_2m.rounded()))° · \(current.description)")
                } else { Text(weather.enabled ? (weather.loading ? "Узнаём погоду…" : "Погода недоступна") : "Своя погода · \(manualMode.title)") }
                Spacer()
                Button { paused.toggle() } label: { Image(systemName: paused ? "play" : "pause") }
                    .help(paused ? "Продолжить эффекты" : "Пауза эффектов")
                Button { compact = false; settings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .help("Эффекты и настройки").accessibilityLabel("Эффекты и настройки")
            }.font(.caption).foregroundStyle(.secondary)
        }
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
                Text("Эффект определяется погодой выбранного города.").font(.caption).foregroundStyle(.secondary)
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
                    if !compact {
                    Button(cameraCollapsed ? "Показать видео" : "Свернуть видео") {
                        expanded = false
                        cameraCollapsed.toggle()
                    }.buttonStyle(.borderless).font(.system(size: 11))
                    Button { cameraCollapsed = false; expanded.toggle() } label: {
                        Image(systemName: expanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                    }.help(expanded ? "Вернуться · Esc" : "Развернуть вид")
                    }
                }
                if !cameraCollapsed {
                InlineCameraView(camera: camera, session: cameraSession, expanded: expanded || compact, collapse: { expanded = false; compact = false })
                    .frame(height: height).clipShape(RoundedRectangle(cornerRadius: 14))
                HStack {
                    Text(cameraSession.status).font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    Link(camera.provider, destination: camera.source).font(.system(size: 10))
                    Button("Обновить") { cameraSession.reload() }.font(.system(size: 11)).buttonStyle(.borderless)
                        .opacity(!compact || hovering ? 1 : 0.35)
                }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "window.ceiling").font(.system(size: 30, weight: .light))
                    Text("Здесь пока нет live-камеры").font(.system(size: 24, design: .serif))
                    Text(compact ? "Выбери другой город в меню сверху." : "Погода города доступна ниже.").font(.caption)
                }.frame(maxWidth: .infinity, minHeight: compact ? 120 : 230, alignment: .center)
            }
            if !compact {
            Button("Мои камеры · добавить / изменить") { editorCity = CityPortrait.matching(city) == .neutral ? city : CityPortrait.matching(city).city; editingCity = true }
                .font(.caption).buttonStyle(.borderless)
            }
        }.padding(compact ? 8 : 14).background(Color.white.opacity(0.7)).cornerRadius(18)
    }
    private func weatherCard(_ city: WeatherCity) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Погода на рабочем столе", systemImage: weather.current?.effect == .sunny ? "sun.max" : "cloud.rain").font(.system(size: 14, weight: .medium))
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
}

struct SoundControls: View {
    @ObservedObject var weather: WeatherStore
    @AppStorage("atmosphereSound") private var sound = false
    @AppStorage("soundSource") private var source = "city"
    @AppStorage("cityAtmosphere") private var atmosphere = false
    @AppStorage("atmosphereVolume") private var cityVolume = 0.25
    @AppStorage("weatherVolume") private var weatherVolume = 0.25
    @AppStorage("florenceBells") private var bells = false
    @AppStorage("mode") private var mode = Mode.snow
    @AppStorage("paused") private var paused = false
    private var effect: Mode? { weather.enabled ? weather.current?.effect : mode }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Звуковой фон", isOn: $sound).toggleStyle(.switch)
                .onChange(of: sound) { on in if on { atmosphere = true } }
            Picker("Источник звука", selection: $source) {
                Text("Звуки города").tag("city")
                Text("Звуки погоды").tag("weather")
            }.pickerStyle(.segmented)
            if source == "weather" {
                Text(effect == .rain ? "Дождь" : effect == .storm ? "Дождь и раскаты грома" : "Для этой погоды звука пока нет — тишина.").font(.caption)
                Slider(value: $weatherVolume, in: 0...1) { Text("Громкость погоды") }
                Text("Дождь звучит непрерывно. Гром — после молнии, с задержкой 0,8–1,8 с.").font(.caption).foregroundStyle(.secondary)
            } else {
                if weather.city.map({ CityPortrait.matching($0) == .florence }) == true {
                    Picker("Запись", selection: $bells) { Text("Площадь").tag(false); Text("Колокола").tag(true) }.pickerStyle(.segmented)
                }
                Slider(value: $cityVolume, in: 0...1) { Text("Громкость города") }
                if weather.city.flatMap({ CityMood(city: $0).soundAsset }) == nil {
                    Text("Для этого города записи пока нет.").font(.caption)
                }
            }
            if paused { Text("Звук на паузе вместе с эффектами.").font(.caption) }
            Text("Отдельно от звука live-камеры").font(.caption).foregroundStyle(.secondary)
        }
    }
}
