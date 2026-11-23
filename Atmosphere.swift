import AppKit
import SpriteKit
import AVFoundation

// Artistic city portraits, not observations of flowering or astronomical sunrise.
enum CityPortrait: String, CaseIterable {
    case moscow, rome, athens, petersburg, tokyo, florence, nizhny, newyork, neutral

    static var destinations: [CityPortrait] { allCases.filter { $0 != .neutral } }
    var city: WeatherCity {
        switch self {
        case .newyork: return WeatherCity(id: -8, name: "Нью-Йорк", latitude: 40.7128, longitude: -74.0060, country: "США", timezone: "America/New_York")
        case .nizhny: return WeatherCity(id: -7, name: "Нижний Новгород", latitude: 56.33, longitude: 44.00, country: "Россия", timezone: "Europe/Moscow")
        case .moscow: return WeatherCity(id: -1, name: "Москва", latitude: 55.75, longitude: 37.62, country: "Россия", timezone: "Europe/Moscow")
        case .rome: return WeatherCity(id: -2, name: "Рим", latitude: 41.9022, longitude: 12.4573, country: "Италия", timezone: "Europe/Rome")
        case .athens: return WeatherCity(id: -3, name: "Афины", latitude: 37.98, longitude: 23.73, country: "Греция", timezone: "Europe/Athens")
        case .petersburg: return WeatherCity(id: -4, name: "Санкт-Петербург", latitude: 59.94, longitude: 30.31, country: "Россия", timezone: "Europe/Moscow")
        case .tokyo: return WeatherCity(id: -5, name: "Токио", latitude: 35.68, longitude: 139.69, country: "Япония", timezone: "Asia/Tokyo")
        case .florence: return WeatherCity(id: -6, name: "Флоренция", latitude: 43.77, longitude: 11.25, country: "Италия", timezone: "Europe/Rome")
        case .neutral: return WeatherCity(id: 0, name: "Другой город", latitude: 0, longitude: 0)
        }
    }
    static func matching(_ city: WeatherCity) -> CityPortrait {
        destinations.first { abs($0.city.latitude - city.latitude) < 0.2 && abs($0.city.longitude - city.longitude) < 0.2 } ?? .neutral
    }
    var detail: String {
        switch self {
        case .newyork: return "Погода и местное время Нью-Йорка."
        case .nizhny: return "Тёплые отражения, ветка из-за края и тихое дыхание воды."
        case .moscow: return "Порыв ветра приоткрывает осеннюю ветку; серебристый свет скользит по краю."
        case .rome: return "Живая хвоя пинии у края, медовый свет и мягкий шелест."
        case .athens: return "Оливковая ветка входит в кадр и покачивается в бело-голубом свете."
        case .petersburg: return "Скользящие отражения, ветер с воды и редкая чайка в светлое время."
        case .tokyo: return "Ветка сакуры весной, клён осенью; ночью — мягкие проходящие отблески."
        case .florence: return "Тосканская хвоя, терракотовый вечерний свет и шелест листвы."
        case .neutral: return "Мягкий свет и редкие сезонные частицы."
        }
    }
}

enum MoodSeason: String { case winter = "Зима", spring = "Весна", summer = "Лето", autumn = "Осень" }
enum MoodLight: String { case dawn = "Рассвет", day = "День", dusk = "Вечер", night = "Ночь", whiteNight = "Белая ночь" }
enum MoodParticle { case glint, petal, leaf, olive, gull }

struct CityMood: Equatable {
    let portrait: CityPortrait
    let season: MoodSeason
    let light: MoodLight
    let overcast: Bool
    let fog: Bool
    let precipitation: Bool

    static func localTime(_ date: Date, city: WeatherCity) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.timeZone = zone(for: city)
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    static func zone(for city: WeatherCity) -> TimeZone {
        let name = city.timezone ?? CityPortrait.matching(city).city.timezone
        // Older saved or unusual API locations may not have a time zone.
        return name.flatMap(TimeZone.init(identifier:)) ?? TimeZone(secondsFromGMT: Int((city.longitude / 15).rounded()) * 3600) ?? .gmt
    }

    init(city: WeatherCity, date: Date = Date(), code: Int? = nil) {
        portrait = CityPortrait.matching(city)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.zone(for: city)
        let month = calendar.component(.month, from: date)
        let localMonth = city.latitude < 0 ? (month + 5) % 12 + 1 : month
        switch localMonth {
        case 3...5: season = .spring
        case 6...8: season = .summer
        case 9...11: season = .autumn
        default: season = .winter
        }
        let hour = Double(calendar.component(.hour, from: date)) + Double(calendar.component(.minute, from: date)) / 60
        // A seasonal lighting schedule: deliberately a stylization, not a sunrise forecast.
        let spread = min(abs(city.latitude) / 15, 4) * cos(Double(localMonth - 6) * .pi / 6)
        let dawn = 6 - spread / 2
        let dusk = 18 + spread / 2
        if portrait == .petersburg && month == 6 && (hour >= 22 || hour < 3) { light = .whiteNight }
        else if hour < dawn - 1 || hour >= dusk + 1 { light = .night }
        else if hour < dawn + 1 { light = .dawn }
        else if hour >= dusk - 1 { light = .dusk }
        else { light = .day }
        overcast = [2, 3, 45, 48].contains(code ?? -1)
        fog = [45, 48].contains(code ?? -1)
        precipitation = code.map { CurrentWeather(temperature_2m: 0, weather_code: $0).codedEffect != nil } ?? false
    }

    var particle: MoodParticle {
        if light == .night { return .glint }
        if portrait == .petersburg && season != .winter { return .gull }
        if portrait == .athens { return .olive }
        if season == .autumn { return .leaf }
        if season == .spring && (portrait == .tokyo || portrait == .neutral) { return .petal }
        return .glint
    }

    var edgeAsset: String? {
        switch portrait {
        case .rome, .florence: return "pine"
        case .athens: return "olive"
        case .tokyo: return season == .spring ? "cherry" : (season == .autumn ? "maple" : nil)
        default: return season == .autumn ? "autumn" : nil
        }
    }
    var soundAsset: String? {
        switch portrait {
        case .florence: return "florence-market"
        case .rome: return "rome-pantheon"
        case .tokyo: return "tokyo-street"
        default: return nil
        }
    }

    var tint: NSColor {
        if light == .whiteNight { return NSColor(calibratedRed: 0.65, green: 0.78, blue: 0.95, alpha: 1) }
        if light == .night {
            if portrait == .nizhny { return NSColor(calibratedRed: 0.92, green: 0.72, blue: 0.44, alpha: 1) }
            return portrait == .tokyo ? NSColor(calibratedRed: 0.83, green: 0.35, blue: 0.64, alpha: 1) : NSColor(calibratedRed: 0.40, green: 0.55, blue: 0.82, alpha: 1)
        }
        if light == .dusk { return NSColor(calibratedRed: 1, green: 0.60, blue: 0.34, alpha: 1) }
        if light == .dawn { return NSColor(calibratedRed: 0.91, green: 0.72, blue: 0.76, alpha: 1) }
        switch portrait {
        case .nizhny: return NSColor(calibratedRed: 0.67, green: 0.81, blue: 0.88, alpha: 1)
        case .rome: return NSColor(calibratedRed: 1, green: 0.80, blue: 0.43, alpha: 1)
        case .athens: return NSColor(calibratedRed: 0.65, green: 0.86, blue: 1, alpha: 1)
        case .florence: return NSColor(calibratedRed: 0.95, green: 0.60, blue: 0.40, alpha: 1)
        case .tokyo: return NSColor(calibratedRed: 1, green: 0.73, blue: 0.81, alpha: 1)
        default: return NSColor(calibratedRed: 0.76, green: 0.85, blue: 1, alpha: 1)
        }
    }
}

// Shared by the live SpriteKit layer and the exported visual previews.
enum AtmosphereArt {
    static func image(size: CGSize, draw: (CGContext) -> Void) -> CGImage {
        let context = CGContext(data: nil, width: max(1, Int(size.width)), height: max(1, Int(size.height)),
            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        draw(context)
        return context.makeImage()!
    }

    static func backdrop(_ mood: CityMood, size: CGSize) -> CGImage {
        image(size: size) { c in
            let w = size.width, h = size.height
            let tint = mood.overcast ? NSColor(calibratedWhite: 0.77, alpha: 1) : mood.tint
            let strength: CGFloat = mood.precipitation ? 0.12 : (mood.light == .night ? 0.23 : 0.28)
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                tint.withAlphaComponent(strength).cgColor, tint.withAlphaComponent(0).cgColor
            ] as CFArray, locations: [0, 1])!
            for point in [CGPoint(x: w * 0.10, y: h), CGPoint(x: w, y: h * 0.12)] {
                c.drawRadialGradient(gradient, startCenter: point, startRadius: 0, endCenter: point,
                    endRadius: min(w * 0.52, h * 0.65), options: [])
            }
            if mood.fog {
                let fog = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
                    NSColor.white.withAlphaComponent(0.10).cgColor, NSColor.white.withAlphaComponent(0).cgColor
                ] as CFArray, locations: [0, 1])!
                c.drawLinearGradient(fog, start: .zero, end: CGPoint(x: 0, y: h * 0.25), options: [])
            }
        }
    }

    static func particle(_ kind: MoodParticle, tint: NSColor) -> CGImage {
        image(size: CGSize(width: 40, height: 40)) { c in
            c.setFillColor(tint.withAlphaComponent(0.8).cgColor)
            c.setStrokeColor(tint.withAlphaComponent(0.75).cgColor)
            c.setLineWidth(1.4)
            switch kind {
            case .glint:
                let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [tint.withAlphaComponent(0.7).cgColor, tint.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
                c.drawRadialGradient(gradient, startCenter: CGPoint(x: 20, y: 20), startRadius: 0, endCenter: CGPoint(x: 20, y: 20), endRadius: 14, options: [])
            case .gull:
                c.move(to: CGPoint(x: 3, y: 18)); c.addQuadCurve(to: CGPoint(x: 20, y: 15), control: CGPoint(x: 10, y: 29))
                c.addQuadCurve(to: CGPoint(x: 37, y: 18), control: CGPoint(x: 30, y: 29)); c.strokePath()
            case .petal:
                c.move(to: CGPoint(x: 20, y: 5)); c.addCurve(to: CGPoint(x: 20, y: 31), control1: CGPoint(x: 1, y: 15), control2: CGPoint(x: 10, y: 38))
                c.addCurve(to: CGPoint(x: 20, y: 5), control1: CGPoint(x: 35, y: 36), control2: CGPoint(x: 39, y: 17)); c.fillPath()
            case .leaf, .olive:
                c.move(to: CGPoint(x: 7, y: 5))
                c.addQuadCurve(to: CGPoint(x: 32, y: 34), control: CGPoint(x: kind == .olive ? 9 : -3, y: 34))
                c.addQuadCurve(to: CGPoint(x: 7, y: 5), control: CGPoint(x: kind == .olive ? 29 : 43, y: 6)); c.fillPath()
                c.setStrokeColor(NSColor.white.withAlphaComponent(0.45).cgColor)
                c.move(to: CGPoint(x: 7, y: 5)); c.addLine(to: CGPoint(x: 32, y: 34)); c.strokePath()
            }
        }
    }
}

enum PresenceAssets {
    static func url(_ name: String, extension ext: String) -> URL? {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("AtmosphereAssets").appendingPathComponent(name + "." + ext)
        if let bundled, FileManager.default.fileExists(atPath: bundled.path) { return bundled }
        let source = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("assets").appendingPathComponent(name + "." + ext)
        return FileManager.default.fileExists(atPath: source.path) ? source : nil
    }
    static func image(_ name: String) -> CGImage? {
        guard let url = url(name, extension: "png"), let image = NSImage(contentsOf: url) else { return nil }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}

@MainActor final class AtmosphereSound {
    private var player: AVAudioPlayer?
    private var track: String?
    private var thunderPlayer: AVAudioPlayer?
    private var thunderJob: DispatchWorkItem?
    private var thunderAllowed = false
    private var thunderContext: Mode?
    private var thunderVolume: Float = 0.25
    func strike() {
        guard thunderAllowed, thunderJob == nil else { return }
        let job = DispatchWorkItem { [weak self] in
            guard let self, self.thunderAllowed else { return }
            self.thunderJob = nil
            guard let url = PresenceAssets.url("weather-thunder", extension: "mp3") else { return }
            self.thunderPlayer?.stop()
            self.thunderPlayer = try? AVAudioPlayer(contentsOf: url)
            self.thunderPlayer?.volume = self.thunderVolume
            self.thunderPlayer?.play()
        }
        thunderJob = job
        DispatchQueue.main.asyncAfter(deadline: .now() + .random(in: 0.8...1.8), execute: job)
    }
    func apply(enabled: Bool, mood: CityMood?, volume: Double, florenceBells: Bool = false, weatherSound: Bool = false, effect: Mode? = nil, lightningEnabled: Bool = true) {
        let allowed = enabled && weatherSound && lightningEnabled
        if !allowed || effect != thunderContext {
            thunderJob?.cancel(); thunderJob = nil
            thunderPlayer?.stop(); thunderPlayer = nil
        }
        thunderAllowed = allowed; thunderContext = effect
        thunderVolume = Float(min(1, max(0, volume))) * 0.5
        thunderPlayer?.volume = thunderVolume
        let selected = weatherSound ? (effect == .storm ? "weather-rain" : effect?.soundAsset) : (mood?.portrait == .florence && florenceBells ? "florence-bells" : mood?.soundAsset)
        guard enabled, let selected, let url = PresenceAssets.url(selected, extension: "mp3") else {
            let old = player; player = nil; track = nil
            old?.setVolume(0, fadeDuration: 0.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { old?.stop() }
            return
        }
        if track != selected {
            let old = player
            old?.setVolume(0, fadeDuration: 0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { old?.stop() }
            player = try? AVAudioPlayer(contentsOf: url)
            track = selected
            player?.numberOfLoops = -1
            player?.volume = 0
            player?.play()
        }
        player?.setVolume(Float(min(1, max(0, volume))) * 0.5, fadeDuration: 0.8)
    }
}

final class AtmosphereNode: SKNode {
    private var city: WeatherCity?
    private var code: Int?
    private var canvas = CGSize.zero
    private var mood: CityMood?
    private let backdrop = SKSpriteNode()
    private let motes = SKNode()
    private let events = SKNode()
    private var elapsed: TimeInterval = 0
    private var nextParticle: TimeInterval = 3
    private var eventClock: TimeInterval = 0
    private var nextEvent: TimeInterval = 1
    private var clockCheck: TimeInterval = 0
    private var particleTexture: SKTexture?
    private var textures: [String: SKTexture] = [:]
    override init() {
        super.init()
        addChild(backdrop); addChild(events); addChild(motes)
        backdrop.anchorPoint = .zero
    }
    required init?(coder: NSCoder) { fatalError() }
    private func texture(_ name: String) -> SKTexture? {
        if let cached = textures[name] { return cached }
        guard let image = PresenceAssets.image(name) else { return nil }
        let result = SKTexture(cgImage: image); textures[name] = result; return result
    }
    func configure(city: WeatherCity?, code: Int?, size: CGSize, strength: Double, paused: Bool) {
        let changed = self.city != city || canvas != size
        self.city = city; self.code = code; canvas = size
        isHidden = city == nil; isPaused = paused; alpha = CGFloat(strength)
        if changed {
            mood = nil; motes.removeAllChildren(); events.removeAllChildren()
            elapsed = 0; nextParticle = 3; eventClock = 0; nextEvent = 1
        }
        if city != nil { refresh() }
        else { backdrop.texture = nil; particleTexture = nil; events.removeAllChildren() }
    }
    func demonstrate() {
        guard city != nil, !isPaused else { return }
        events.removeAllChildren(); eventClock = 0; nextEvent = 28
        showEvent()
    }
    private func refresh() {
        guard let city else { return }
        let next = CityMood(city: city, code: code)
        guard next != mood else { return }
        mood = next; motes.removeAllChildren(); events.removeAllChildren()
        let scale = min(1, 1600 / max(canvas.width, 1))
        backdrop.texture = SKTexture(cgImage: AtmosphereArt.backdrop(next, size: CGSize(width: canvas.width * scale, height: canvas.height * scale)))
        backdrop.size = canvas
        let tint: NSColor = next.particle == .leaf ? .systemOrange : (next.particle == .olive ? NSColor(calibratedRed: 0.69, green: 0.77, blue: 0.59, alpha: 1) : next.tint)
        particleTexture = next.particle == .gull ? texture("gull") : SKTexture(cgImage: AtmosphereArt.particle(next.particle, tint: tint))
        backdrop.removeAllActions()
        backdrop.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 13), .fadeAlpha(to: 0.9, duration: 19)])))
    }
    private func showEvent() {
        guard let mood, events.children.count < 3 else { return }
        // Foreground detail swings in from outside the screen and then retreats.
        if let asset = mood.edgeAsset, let image = texture(asset) {
            let branch = SKSpriteNode(texture: image)
            let width = min(520, canvas.width * 0.36)
            branch.size = CGSize(width: width, height: width * image.size().height / image.size().width)
            branch.anchorPoint = CGPoint(x: 1, y: 0.5)
            let resting = CGPoint(x: canvas.width + width * 0.10, y: canvas.height * 0.72)
            branch.position = CGPoint(x: canvas.width + width * 0.92, y: resting.y + 20)
            branch.alpha = 0
            events.addChild(branch)
            let entrance = SKAction.move(to: resting, duration: 5); entrance.timingMode = .easeInEaseOut
            let leave = SKAction.moveBy(x: width, y: 30, duration: 6); leave.timingMode = .easeInEaseOut
            let sway = SKAction.sequence([.rotate(toAngle: 0.035, duration: 3.2), .rotate(toAngle: -0.025, duration: 4.1)])
            sway.timingMode = .easeInEaseOut
            branch.run(.repeatForever(sway))
            branch.run(.sequence([.group([entrance, .fadeAlpha(to: mood.light == .night ? 0.67 : 0.86, duration: 4)]),
                .wait(forDuration: 12), .group([leave, .fadeOut(withDuration: 5)]), .removeFromParent()]))
        }
        // A wide, defocused reflection travels along the edge; never a hard skyline.
        let light = SKSpriteNode(texture: SKTexture(cgImage: AtmosphereArt.particle(.glint, tint: mood.tint)))
        light.size = CGSize(width: min(680, canvas.width * 0.5), height: 160)
        light.position = CGPoint(x: canvas.width + 150, y: canvas.height * 0.20)
        light.alpha = 0; events.addChild(light)
        light.run(.sequence([.group([.moveBy(x: -canvas.width * 0.7, y: 35, duration: 20),
            .sequence([.fadeAlpha(to: 0.28, duration: 5), .wait(forDuration: 7), .fadeOut(withDuration: 8)])]), .removeFromParent()]))
    }
    func tick(_ dt: TimeInterval) {
        guard city != nil, !isPaused else { return }
        clockCheck += dt
        if clockCheck >= 60 { clockCheck = 0; refresh() }
        eventClock += dt
        if eventClock >= nextEvent { eventClock = 0; nextEvent = .random(in: 32...48); showEvent() }
        guard let mood, !mood.precipitation else { return }
        elapsed += dt
        guard elapsed >= nextParticle, motes.children.count < 8, let texture = particleTexture else { return }
        elapsed = 0
        nextParticle = mood.particle == .gull ? .random(in: 35...60) : .random(in: 5...10)
        let node = SKSpriteNode(texture: texture)
        let width: CGFloat = mood.particle == .gull ? 92 : .random(in: 12...24)
        node.size = CGSize(width: width, height: mood.particle == .gull ? width * texture.size().height / texture.size().width : width)
        node.position = CGPoint(x: canvas.width + width, y: mood.particle == .gull ? canvas.height * 0.8 : .random(in: (canvas.height * 0.62)...canvas.height))
        node.alpha = 0; motes.addChild(node)
        let duration: TimeInterval = mood.particle == .gull ? 24 : 30
        let drift = SKAction.moveBy(x: -canvas.width - width * 2, y: mood.particle == .gull ? -canvas.height * 0.12 : -canvas.height * 0.5, duration: duration)
        let sway = SKAction.repeatForever(.sequence([.moveBy(x: 0, y: 8, duration: 2.5), .moveBy(x: 0, y: -8, duration: 2.5)]))
        node.run(sway)
        if mood.particle != .gull { node.run(.rotate(byAngle: 2, duration: duration)) }
        node.run(.sequence([.group([drift, .sequence([.fadeAlpha(to: 0.72, duration: 3), .wait(forDuration: duration - 7), .fadeOut(withDuration: 4)])]), .removeFromParent()]))
    }
}

// Feathered ellipses: every pixel at the texture boundary is transparent.
final class SunlightNode: SKNode {
    private static let vapor: SKTexture = {
        let pixels = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 1024, bitsPerPixel: 32)!
        let data = pixels.bitmapData!
        for y in 0..<256 { for x in 0..<256 {
            let u = (Double(x) - 127.5) / 127.5, v = (Double(y) - 127.5) / 127.5
            let alpha = pow(max(0, 1 - u*u - v*v), 4)
            let i = y * 1024 + x * 4
            let a = UInt8(alpha * 255)
            data[i] = a; data[i+1] = a; data[i+2] = a; data[i+3] = a
        } }
        return SKTexture(cgImage: pixels.cgImage!)
    }()
    private let glow = SKSpriteNode(texture: vapor)
    private var rays: [SKSpriteNode] = []
    private var dust: [SKSpriteNode] = []
    private var active = false, dustEnabled = true, test = false
    private var city: WeatherCity?
    private var canvas = CGSize.zero
    private var clock: CGFloat = 0, episode: CGFloat = -1, wait: CGFloat = .random(in: 180...420)
    private var strength: CGFloat = 0.9
    override init() {
        super.init()
        addChild(glow)
        for _ in 0..<3 { let ray = SKSpriteNode(texture: Self.vapor); rays.append(ray); addChild(ray) }
        for _ in 0..<32 { let dot = SKSpriteNode(texture: Self.vapor); dust.append(dot); addChild(dot) }
        isHidden = true
    }
    required init?(coder: NSCoder) { fatalError() }
    func configure(active: Bool, city: WeatherCity?, size: CGSize, dust: Bool, strength: CGFloat) {
        if self.active != active || self.city != city { episode = -1; test = false; wait = .random(in: 180...420) }
        self.active = active; self.city = city; canvas = size; dustEnabled = dust; self.strength = strength
        render()
    }
    func preview() { test = true; episode = 0; render() }
    private var light: MoodLight {
        if test { return .day }
        if let city { return CityMood(city: city).light }
        let h = Calendar.current.component(.hour, from: Date())
        return h < 6 || h >= 21 ? .night : h < 9 ? .dawn : h >= 17 ? .dusk : .day
    }
    func tick(_ dt: CGFloat) {
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !reduced { clock += dt }
        if episode >= 0 {
            episode += dt
            if episode >= 20 { episode = -1; test = false; wait = .random(in: 180...420) }
        } else if active && dustEnabled && light != .night && !reduced {
            wait -= dt
            if wait <= 0 { episode = 0 }
        }
        render()
    }
    private func render() {
        isHidden = !active && !test
        guard !isHidden else { return }
        let night = light == .night
        let tint: NSColor = night ? NSColor(red: 0.72, green: 0.8, blue: 1, alpha: 1) : light == .dusk ? NSColor(red: 1, green: 0.65, blue: 0.31, alpha: 1) : light == .dawn ? NSColor(red: 1, green: 0.85, blue: 0.56, alpha: 1) : NSColor(red: 1, green: 0.97, blue: 0.86, alpha: 1)
        let scale = min(canvas.width / 1000, canvas.height / 700)
        let pulse = episode >= 0 ? min(1, episode / 4) * min(1, (20 - episode) / 5) : 0
        glow.color = tint; glow.colorBlendFactor = 1
        glow.size = CGSize(width: 640 * scale, height: 460 * scale)
        glow.position = CGPoint(x: 25 * scale, y: canvas.height - 20 * scale)
        glow.alpha = (night ? 0.035 : 0.14 + pulse * 0.04) * strength
        for (i, ray) in rays.enumerated() {
            ray.color = tint; ray.colorBlendFactor = 1
            ray.size = CGSize(width: (120 + CGFloat(i) * 45 + pulse * 55) * scale, height: (560 + CGFloat(i) * 90) * scale)
            ray.position = CGPoint(x: (135 + CGFloat(i) * 75) * scale, y: canvas.height - (175 + CGFloat(i) * 45) * scale)
            ray.zRotation = 0.4 + CGFloat(i) * 0.11 + sin(clock / 22 + CGFloat(i)) * 0.025
            ray.alpha = night ? 0 : (0.055 + pulse * 0.08) * strength
        }
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        for (i, dot) in dust.enumerated() {
            let phase = CGFloat(i) * 2.39996
            let u = sin(phase + clock * 0.11) * 0.85
            let v = sin(phase * 1.7 + clock * 0.06) * 0.9
            let mask = max(0, 1 - u*u - v*v)
            let x = u * 75, y = v * 260
            dot.position = CGPoint(x: (210 + x * cos(0.5) - y * sin(0.5)) * scale,
                                   y: canvas.height - 240 * scale + (x * sin(0.5) + y * cos(0.5)) * scale)
            let d = (1.5 + CGFloat(i % 5) * 0.55) * scale
            dot.size = CGSize(width: d, height: d)
            dot.color = tint; dot.colorBlendFactor = 1
            dot.alpha = night || !dustEnabled || reduced ? 0 : pulse * mask * 0.36 * strength
        }
    }
}
