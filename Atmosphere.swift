import AppKit
import SpriteKit
import AVFoundation

// Artistic city portraits, not observations of flowering or astronomical sunrise.
enum CityPortrait: String, CaseIterable {
    case moscow, rome, athens, petersburg, tokyo, florence, nizhny, neutral

    static var destinations: [CityPortrait] { allCases.filter { $0 != .neutral } }
    var city: WeatherCity {
        switch self {
        case .nizhny: return WeatherCity(id: -7, name: "Нижний Новгород", latitude: 56.33, longitude: 44.00, country: "Россия", timezone: "Europe/Moscow")
        case .moscow: return WeatherCity(id: -1, name: "Москва", latitude: 55.75, longitude: 37.62, country: "Россия", timezone: "Europe/Moscow")
        case .rome: return WeatherCity(id: -2, name: "Рим", latitude: 41.90, longitude: 12.50, country: "Италия", timezone: "Europe/Rome")
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
        precipitation = code.map { CurrentWeather(temperature_2m: 0, weather_code: $0).effect != nil } ?? false
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
    var soundAsset: String {
        if precipitation { return "rain" }
        if portrait == .petersburg || portrait == .nizhny { return "water" }
        if portrait == .rome || portrait == .florence || portrait == .athens { return "leaves" }
        return "wind"
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
    func apply(enabled: Bool, mood: CityMood?, volume: Double) {
        guard enabled, let mood, let url = PresenceAssets.url(mood.soundAsset, extension: "wav") else {
            let old = player; player = nil; track = nil
            old?.setVolume(0, fadeDuration: 0.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { old?.stop() }
            return
        }
        if track != mood.soundAsset {
            let old = player
            old?.setVolume(0, fadeDuration: 0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { old?.stop() }
            player = try? AVAudioPlayer(contentsOf: url)
            track = mood.soundAsset
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
