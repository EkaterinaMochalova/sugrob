// Сугроб — снег, листья, дождь или лепестки поверх рабочего стола macOS.
// Снег оседает на верхних краях окон и внизу экрана, разлетается от курсора
// и осыпается, когда окно двигают или закрывают.
// Настройки — обычное окно. Оно открывается тремя путями, и хотя бы один работает всегда:
// значок в строке меню, значок в Dock (по желанию) и повторный запуск приложения
// (Spotlight, Launchpad, Finder).

import AppKit
import ServiceManagement
import SpriteKit
import SwiftUI

let defaultSettings: [String: Any] = [
    "mode": Mode.snow.rawValue, "intensity": 1.0, "speed": 1.0, "size": 1.0, "opacity": 0.9,
    "paused": false, "behindWindows": false, "overFullScreen": false, "hideInScreenshots": true,
    "onWindows": true, "onGround": true, "cursor": true, "drift": 2500.0,
    "showInMenuBar": true, "showInDock": false, "cityAtmosphere": false, "atmosphereStrength": 0.65, "atmosphereSound": false, "atmosphereVolume": 0.25, "weatherVolume": 0.25, "soundSource": "city",
]

extension Notification.Name {
    static let clearAll = Notification.Name("SugrobClearAll")
}

// MARK: - Картинки частиц (рисуются кодом, белые; цвет задаёт спрайт)

func sprite(_ w: Int, _ h: Int, _ draw: (CGRect) -> Void) -> SKTexture {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    draw(CGRect(x: 0, y: 0, width: w, height: h))
    NSGraphicsContext.restoreGraphicsState()
    return SKTexture(cgImage: ctx.makeImage()!)
}

let flakeTexture = sprite(32, 32) { r in
    let clear = NSColor.white.withAlphaComponent(0)
    NSGradient(colorsAndLocations: (.white, 0), (.white, 0.45), (clear, 1))!
        .draw(in: NSBezierPath(ovalIn: r), relativeCenterPosition: .zero)
}
let leafTexture = sprite(40, 54) { r in
    NSColor(calibratedRed: 0.70, green: 0.46, blue: 0.20, alpha: 1).setFill()
    NSBezierPath(ovalIn: r.insetBy(dx: 8, dy: 3)).fill()
}
let leafTextures: [SKTexture] = ["ochre", "rust", "olive"].compactMap { name in
    guard let url = Bundle.main.url(forResource: "leaf-" + name, withExtension: "png", subdirectory: "AtmosphereAssets"),
          let image = NSImage(contentsOf: url) else { return nil }
    return SKTexture(image: image)
}
let petalTexture = sprite(16, 26) { r in
    NSColor.white.set()
    NSBezierPath(ovalIn: r.insetBy(dx: 1, dy: 1)).fill()
}
let petalTextures: [SKTexture] = ["blush", "curled"].compactMap { name in
    guard let url = Bundle.main.url(forResource: "petal-" + name, withExtension: "png", subdirectory: "AtmosphereAssets"),
          let image = NSImage(contentsOf: url) else { return nil }
    return SKTexture(image: image)
}
let dropTexture = sprite(8, 64) { r in
    NSGradient(colorsAndLocations: (.white.withAlphaComponent(0), 0), (.white, 0.65), (.white.withAlphaComponent(0), 1))!.draw(in: r, angle: -90)
    NSGraphicsContext.current?.cgContext.setBlendMode(.destinationIn)
    NSGradient(colorsAndLocations: (.white.withAlphaComponent(0), 0), (.white, 0.5), (.white.withAlphaComponent(0), 1))!.draw(in: r, angle: 0)
}

/// Как выглядит и падает один вид частиц. Скорости в пунктах в секунду.
struct Look {
    let texture: SKTexture, aspect: CGFloat, colors: [NSColor], alpha: ClosedRange<CGFloat>
    let rate: CGFloat // штук в секунду на 1440 пунктов ширины экрана
    let fall: CGFloat // скорость падения
    let drag: CGFloat // как быстро частица теряет толчок и возвращается к падению
    let sway: CGFloat // скорость покачивания вбок; размах ≈ sway / 3,5 пункта
    let spin: CGFloat // вращение, радиан в секунду
    let size: ClosedRange<CGFloat> // высота частицы
    let bump: CGFloat // на сколько частица поднимает сугроб, доля её высоты
    let settles: Bool
    let solidDrift: Bool // сугроб рисуется сплошной белой полосой, а лежащие частицы прячутся
}

let cloudFallbackTexture = sprite(480, 180) { _ in
    for (x, y, w, h) in [(30.0, 28.0, 240.0, 100.0), (140, 28, 220, 135), (240, 25, 210, 105)] {
        let path = NSBezierPath(ovalIn: CGRect(x: x, y: y, width: w, height: h))
        NSGradient(colorsAndLocations: (NSColor(white: 1, alpha: 0.95), 0),
            (NSColor(white: 0.97, alpha: 0.92), 0.45),
            (NSColor(white: 0.60, alpha: 0.72), 0.78), (NSColor(white: 0.60, alpha: 0), 1))!
            .draw(in: path, relativeCenterPosition: .zero)
    }
}
let cloudTexture: SKTexture = {
    guard let url = Bundle.main.url(forResource: "cloud-cumulus", withExtension: "png", subdirectory: "AtmosphereAssets"),
          let image = NSImage(contentsOf: url) else { return cloudFallbackTexture }
    return SKTexture(image: image)
}()
let cloudTextures: [SKTexture] = ["stratus", "ragged", "cirrus"].compactMap { name in
    guard let url = Bundle.main.url(forResource: "cloud-" + name, withExtension: "png", subdirectory: "AtmosphereAssets"),
          let image = NSImage(contentsOf: url) else { return nil }
    return SKTexture(image: image)
}
func makeLook(_ mode: Mode) -> Look {
    switch mode {
    case .clouds:
        return Look(texture: cloudTexture, aspect: cloudTexture.size().width / cloudTexture.size().height, colors: [.white], alpha: 0.22...0.36,
                    rate: 0.025, fall: 0, drag: 0, sway: 0, spin: 0, size: 90...140,
                    bump: 0, settles: false, solidDrift: false)
    case .snow:
        // Подогнано по записи Snowhush: много мелких тусклых снежинок, частое мелкое покачивание, сплошной сугроб.
        return Look(texture: flakeTexture, aspect: 1, colors: [.white], alpha: 0.35...0.95, rate: 45, fall: 90,
                    drag: 1.5, sway: 25, spin: 0, size: 1.5...4, bump: 0.5, settles: true, solidDrift: true)
    case .leaves:
        return Look(texture: leafTexture, aspect: 0.75, colors: [.white],
                    alpha: 0.85...1, rate: 8, fall: 65, drag: 1.2, sway: 32, spin: 0.7, size: 24...46, bump: 0.15,
                    settles: true, solidDrift: false)
    case .rain, .storm:
        return Look(texture: dropTexture, aspect: 1.0 / 14, colors: [.white], alpha: 0.18...0.42, rate: 110, fall: 640,
                    drag: 8, sway: 0, spin: 0, size: 14...26, bump: 0, settles: false, solidDrift: false)
    case .petals:
        return Look(texture: petalTexture, aspect: 16.0 / 26,
                    colors: [NSColor(red: 1, green: 0.78, blue: 0.85, alpha: 1), NSColor(red: 1, green: 0.9, blue: 0.93, alpha: 1)],
                    alpha: 0.85...1, rate: 10, fall: 70, drag: 1.3, sway: 35, spin: 0.8, size: 13...23, bump: 0.15,
                    settles: true, solidDrift: false)
    }
}

// MARK: - Симуляция

let columnWidth: CGFloat = 4
private let snowSmoothingWeights = (-6...6).map { exp(-CGFloat($0 * $0) / 12.5) }

final class Flake {
    let node: SKSpriteNode
    var vx: CGFloat = 0, vy: CGFloat = 0
    let phase = CGFloat.random(in: 0...(2 * .pi))
    let freq = CGFloat.random(in: 2.5...4.5) // частота покачивания, рад/с
    var weight: CGFloat = 1 // множитель скорости падения и покачивания: дальние медленнее
    var spin: CGFloat = 0
    var surface: Surface? // на чём лежит; nil — падает
    var column = 0
    var bump: CGFloat = 0
    var collectsOnWindows = CGFloat.random(in: 0..<1) < 0.15
    init(node: SKSpriteNode) { self.node = node }
}

/// Верхний край окна или низ экрана. Сугроб на нём — высоты по столбикам шириной columnWidth.
final class Surface {
    let x0, top, width, maxHeight: CGFloat
    var heights: [CGFloat]
    var visible: [Bool] // столбик не закрыт окном, которое стоит впереди
    var flakes: [Flake] = []
    let shape = SKShapeNode() // сплошной сугроб
    var dirty = false

    init(x0: CGFloat, top: CGFloat, width: CGFloat, maxHeight: CGFloat) {
        self.x0 = x0
        self.top = top
        self.width = width
        self.maxHeight = maxHeight
        let n = max(1, Int(width / columnWidth))
        heights = Array(repeating: 0, count: n)
        visible = Array(repeating: true, count: n)
        shape.fillColor = .white
        shape.strokeColor = .clear
        shape.lineWidth = 0
        shape.alpha = 0.95
        shape.zPosition = 1 // поверх падающих: при ignoresSiblingOrder иначе порядок не определён
    }

    func column(_ x: CGFloat) -> Int { min(max(Int((x - x0) / columnWidth), 0), heights.count - 1) }

    /// Контур сугроба по сглаженным высотам столбиков.
    func redraw() {
        dirty = false
        guard heights.contains(where: { $0 > 0 }) else {
            shape.path = nil
            return
        }
        // A wider, Gaussian profile avoids sharp peaks without changing stored snow mass.
        let smooth = heights.indices.map { i -> CGFloat in
            var sum: CGFloat = 0, weight: CGFloat = 0
            for offset in -6...6 {
                let j = i + offset
                guard heights.indices.contains(j) else { continue }
                let w = snowSmoothingWeights[offset + 6]
                sum += heights[j] * w; weight += w
            }
            return sum / max(weight, 0.001)
        }
        let points = smooth.enumerated().map {
            CGPoint(x: x0 + (CGFloat($0.offset) + 0.5) * columnWidth, y: top + $0.element)
        }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x0, y: top))
        path.addLine(to: CGPoint(x: x0, y: points[0].y))
        for i in points.indices {
            let next = i + 1 < points.count ? points[i + 1] : CGPoint(x: x0 + width, y: points[i].y)
            let midpoint = CGPoint(x: (points[i].x + next.x) / 2, y: (points[i].y + next.y) / 2)
            path.addQuadCurve(to: midpoint, control: points[i])
        }
        path.addLine(to: CGPoint(x: x0 + width, y: points.last!.y))
        path.addLine(to: CGPoint(x: x0 + width, y: top))
        path.closeSubpath()
        shape.path = path
    }
}

/// Одна сцена на экран. Координаты локальные для экрана, y вверх, ноль внизу.
final class RainBead {
    let node = SKShapeNode(ellipseOf: CGSize(width: 5, height: 2.5))
    let surface: Surface
    let x: CGFloat
    var age: CGFloat = 0
    init(surface: Surface, x: CGFloat) {
        self.surface = surface; self.x = x
        node.fillColor = NSColor(calibratedRed: 0.68, green: 0.81, blue: 0.9, alpha: 0.65)
        node.strokeColor = .white.withAlphaComponent(0.4)
        node.lineWidth = 0.5
    }
}
final class SnowScene: SKScene {
    private var beads: [RainBead] = []
    var intensity: CGFloat = 1, speedFactor: CGFloat = 1, sizeFactor: CGFloat = 1
    var snowing = true, cursor = true
    var maxResting = 2500
    var onGround = true { didSet { if !onGround { drop(ground) } } }
    var onWindows = true {
        didSet {
            guard !onWindows else { return }
            for s in windows.values {
                drop(s)
                s.shape.removeFromParent()
            }
            windows = [:]
            order = []
            lastWindowRects = []
        }
    }
    let atmosphere = AtmosphereNode()
    let field = SKNode() // все частицы; его прозрачность — настройка «Непрозрачность»

    private var stormWait: CGFloat = 8
    private var lightning: SKShapeNode?
    private var lastLightningPreview: TimeInterval = -100
    private var lightningAge: CGFloat = 0
    private var cloudIndex = 0
    private var mode: Mode?
    private var look = makeLook(.snow)
    private let origin: CGPoint
    private let ground: Surface
    private var windows: [Int: Surface] = [:]
    private var order: [(id: Int, rect: CGRect)] = [] // окна с верхним краем на этом экране, спереди назад
    private var falling: [Flake] = []
    private var resting: [Flake] = [] // в порядке оседания: старые тают первыми
    private var lastTime: TimeInterval = 0, lastScan: TimeInterval = 0
    private var clock: CGFloat = 0, spawnDebt: CGFloat = 0
    private var lastMouse: CGPoint?
    private var lastWindowRects: [(id: Int, rect: CGRect)] = []

    init(screen: NSScreen) {
        origin = screen.frame.origin
        ground = Surface(x0: 0, top: 0, width: screen.frame.width, maxHeight: 24)
        super.init(size: screen.frame.size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        addChild(atmosphere)
        addChild(field)
        field.addChild(ground.shape)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setMode(_ newMode: Mode) {
        guard newMode != mode else { return }
        let first = mode == nil
        mode = newMode
        lightning?.removeFromParent(); lightning = nil; stormWait = 8
        look = makeLook(newMode)
        if !first {
            // Never let old snow/leaf sprites acquire the new rain physics.
            falling.forEach { $0.node.removeFromParent() }; falling.removeAll()
            resting.forEach { $0.node.removeFromParent() }; resting.removeAll()
            beads.forEach { $0.node.removeFromParent() }; beads.removeAll()
            for s in [ground] + Array(windows.values) {
                s.flakes.removeAll(); s.heights = Array(repeating: 0, count: s.heights.count)
                s.dirty = true
            }
            spawnDebt = 0
        }
        if newMode == .clouds {
            for i in 0..<5 { spawn(); falling.last?.node.position.x = size.width * (0.04 + CGFloat(i) * 0.23) }
        }
    }

    func hideLightning() { childNode(withName: "lightningPreview")?.removeFromParent(); lightning?.removeFromParent(); lightning = nil; stormWait = 8 }
    private func updateLightning(_ dt: CGFloat) {
        guard mode == .storm, snowing,
              UserDefaults.standard.object(forKey: "lightning") as? Bool != false,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            lightning?.removeFromParent(); lightning = nil; stormWait = 8; return
        }
        if let bolt = lightning {
            lightningAge += dt
            bolt.alpha = exp(-lightningAge * 7) * 0.9
            if lightningAge >= 0.65 { bolt.removeFromParent(); lightning = nil }
        }
        stormWait -= dt
        guard stormWait <= 0 else { return }
        stormWait = .random(in: 12...24)
        let bolt = makeLightning()
        field.addChild(bolt); lightning = bolt; lightningAge = 0
        NotificationCenter.default.post(name: .lightningStrike, object: self)
    }
    private func makeLightning() -> SKShapeNode {
        // Midpoint displacement gives branching channels, rather than a regular zigzag.
        func channel(_ start: CGPoint, _ end: CGPoint, _ spread: CGFloat, _ levels: Int) -> [CGPoint] {
            var points = [start, end]
            var amplitude = spread
            for _ in 0..<levels {
                var next: [CGPoint] = [points[0]]
                for i in 1..<points.count {
                    let a = points[i - 1], b = points[i]
                    next.append(CGPoint(x: min(size.width - 4, max(4, (a.x + b.x) / 2 + .random(in: -amplitude...amplitude))),
                                        y: (a.y + b.y) / 2))
                    next.append(b)
                }
                points = next; amplitude *= 0.52
            }
            return points
        }
        func stroke(_ points: [CGPoint], _ width: CGFloat, _ glow: CGFloat) -> SKShapeNode {
            let path = CGMutablePath(); path.move(to: points[0])
            points.dropFirst().forEach { path.addLine(to: $0) }
            let node = SKShapeNode(path: path)
            node.strokeColor = .white; node.lineWidth = width; node.glowWidth = glow
            return node
        }
        let start = CGPoint(x: size.width * .random(in: 0.35...0.65), y: size.height)
        let end = CGPoint(x: min(size.width * 0.85, max(size.width * 0.15, start.x + size.width * .random(in: -0.2...0.2))), y: size.height * 0.02)
        let trunk = channel(start, end, size.width * 0.09, 6)
        let bolt = stroke(trunk, 2.4, 9)
        bolt.alpha = 0.9
        for i in stride(from: 8, through: 48, by: 5) {
            let origin = trunk[i]
            let side: CGFloat = i % 2 == 0 ? -1 : 1
            let tip = CGPoint(x: min(size.width - 8, max(8, origin.x + side * size.width * .random(in: 0.12...0.35))),
                              y: max(8, origin.y - size.height * .random(in: 0.12...0.38)))
            let branch = channel(origin, tip, size.width * 0.035, 4)
            let node = stroke(branch, 0.9, 3); node.alpha = 0.62; bolt.addChild(node)
            for j in [5, 10] {
                let twigEnd = CGPoint(x: min(size.width - 4, max(4, branch[j].x + side * size.width * .random(in: 0.04...0.12))),
                                      y: max(4, branch[j].y - size.height * .random(in: 0.04...0.13)))
                let twig = stroke(channel(branch[j], twigEnd, size.width * 0.012, 3), 0.45, 1)
                twig.alpha = 0.38; bolt.addChild(twig)
            }
        }
        return bolt
    }
    func previewLightning() {
        let now = ProcessInfo.processInfo.systemUptime
        guard !isPaused, now - lastLightningPreview >= 3,
              UserDefaults.standard.object(forKey: "lightning") as? Bool != false,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        lastLightningPreview = now
        let bolt = makeLightning()
        NotificationCenter.default.post(name: .lightningStrike, object: self)
        bolt.name = "lightningPreview"
        addChild(bolt)
        bolt.run(.sequence([.customAction(withDuration: 0.65) { node, time in node.alpha = exp(-time * 7) * 0.9 }, .removeFromParent()]))
    }

    override func update(_ currentTime: TimeInterval) {
        let raw = CGFloat(min(currentTime - lastTime, 0.05))
        lastTime = currentTime
        guard raw > 0, !isPaused else { return }
        atmosphere.tick(TimeInterval(raw))
        updateLightning(raw)
        let dt = raw * speedFactor
        clock += dt

        if currentTime - lastScan > 0.1 {
            lastScan = currentTime
            scanWindows()
        }
        if snowing && falling.count < (mode == .clouds ? 7 : 5000) {
            spawnDebt += look.rate * intensity * size.width / 1440 * raw
            while spawnDebt >= 1 {
                spawnDebt -= 1
                spawn()
            }
        }
        if cursor && mode != .rain && mode != .storm && mode != .clouds { pushByCursor(raw) } else { lastMouse = nil }
        fall(dt)
        updateBeads(dt)
        while resting.count > maxResting {
            let f = resting.removeFirst()
            if f.surface != nil { melt(f) }
        }
        for s in [ground] + Array(windows.values) where s.dirty {
            s.redraw()
            s.shape.isHidden = !look.solidDrift
        }
    }

    private func spawn() {
        // Глубина: 0 — далеко (мелкая, тусклая, медленная), 1 — близко. Без неё снег выглядит плоской сеткой точек.
        let depth = CGFloat.random(in: 0...1)
        let h = (look.size.lowerBound + (look.size.upperBound - look.size.lowerBound) * depth) * (mode == .clouds ? min(sizeFactor, 1.2) : sizeFactor)
        let cloud = cloudTextures.isEmpty ? look.texture : cloudTextures[cloudIndex % cloudTextures.count]
        let texture = mode == .clouds ? cloud : mode == .leaves ? (leafTextures.randomElement() ?? look.texture) : mode == .petals ? (petalTextures.randomElement() ?? look.texture) : look.texture
        let aspect = (mode == .leaves || mode == .petals || mode == .clouds) ? texture.size().width / texture.size().height : look.aspect
        let node = SKSpriteNode(texture: texture, color: look.colors.randomElement()!,
                                size: CGSize(width: h * aspect, height: h))
        node.colorBlendFactor = (mode == .leaves || mode == .petals || mode == .clouds) ? 0 : 1
        node.alpha = look.alpha.lowerBound + (look.alpha.upperBound - look.alpha.lowerBound) * depth
        node.position = CGPoint(x: .random(in: -40...(size.width + 40)), y: size.height + h)
        if mode == .clouds {
            node.size.width = min(500, node.size.width * .random(in: 0.85...1.1))
            node.xScale = cloudIndex % 2 == 0 ? 1 : -1
            cloudIndex += 1
            node.position = CGPoint(x: -node.size.width, y: size.height - min(150, size.height * .random(in: 0.08...0.16)))
        }
        if (mode == .rain || mode == .storm) { node.zRotation = -0.04 }
        if look.spin > 0 { node.zRotation = .random(in: 0...(2 * .pi)) }
        field.addChild(node)
        let f = Flake(node: node)
        f.weight = 0.6 + 0.6 * depth
        f.vy = -look.fall * f.weight
        f.spin = .random(in: -look.spin...look.spin)
        falling.append(f)
    }

    private func fall(_ dt: CGFloat) {
        let k = min(1, look.drag * dt)
        var i = 0
        while i < falling.count {
            let f = falling[i]
            let p = f.node.position
            if mode == .clouds {
                f.node.position.x += dt * (4 + f.weight * 3)
                if f.node.position.x > size.width + f.node.size.width {
                    f.node.removeFromParent(); falling.remove(at: i)
                } else { i += 1 }
                continue
            }
            // vx — толчки и ветер, они гаснут; покачивание добавляется отдельно, чтобы сопротивление его не гасило.
            f.vx -= f.vx * k
            f.vy += (-look.fall * f.weight - f.vy) * k
            let sway = sin(clock * f.freq + f.phase) * look.sway * f.weight
            let np = CGPoint(x: p.x + (f.vx + sway + ((mode == .rain || mode == .storm) ? -24 : 0)) * dt, y: p.y + f.vy * dt)
            f.node.position = np
            f.node.zRotation += f.spin * dt
            if mode == .leaves || mode == .petals { f.node.xScale = 0.35 + 0.65 * abs(sin(clock * 1.3 + f.phase)) }

            let out = np.y < -30 || np.x < -80 || np.x > size.width + 80 || np.y > size.height + 400
            if !out, (mode == .rain || mode == .storm), let s = landing(x: np.x, y: np.y, prevY: p.y), CGFloat.random(in: 0...1) < 0.12 {
                if let bead = beads.first(where: { $0.surface === s && abs($0.x - np.x) < 8 && $0.age < 1.5 }) {
                    bead.node.xScale = min(2, bead.node.xScale + 0.2)
                } else if beads.count < 100 {
                    let bead = RainBead(surface: s, x: np.x)
                    bead.node.position = CGPoint(x: np.x, y: s.top)
                    field.addChild(bead.node); beads.append(bead)
                }
            }
            var gone = out
            if out {
                f.node.removeFromParent()
            } else if look.settles, f.vy < 0, let s = landing(x: np.x, y: np.y, prevY: p.y), s === ground || f.collectsOnWindows {
                // Most particles pass in front; only a small background layer settles.
                // Rain passes over windows and exits below the screen.
                gone = settle(f, on: s)
            }
            if gone {
                falling.swapAt(i, falling.count - 1)
                falling.removeLast()
            } else {
                i += 1
            }
        }
    }

    private func updateBeads(_ dt: CGFloat) {
        beads.removeAll { bead in
            let s = bead.surface
            let valid = s === ground ? onGround : onWindows && windows.values.contains(where: { $0 === s })
            guard (mode == .rain || mode == .storm), valid, s.visible[s.column(bead.x)], bead.age < 4 else {
                bead.node.removeFromParent(); return true
            }
            bead.age += dt
            let slide = max(0, bead.age - 1.5)
            bead.node.position = CGPoint(x: bead.x, y: s.top - slide * slide * 10)
            bead.node.yScale = 1 + min(2, slide)
            bead.node.alpha = min(1, max(0, (4 - bead.age) / 1.5))
            return false
        }
    }

    /// Куда упала частица на этом шаге: на окно (переднее важнее) или на низ экрана.
    private func landing(x: CGFloat, y: CGFloat, prevY: CGFloat) -> Surface? {
        if onWindows {
            for w in order where x >= w.rect.minX && x < w.rect.maxX {
                guard let s = windows[w.id] else { continue }
                let c = s.column(x)
                // prevY >= top: частица пришла сверху, а не летит перед окном.
                if s.visible[c], prevY >= s.top, y <= s.top + s.heights[c] { return s }
            }
        }
        if onGround, x >= 0, x < size.width, y <= ground.heights[ground.column(x)] { return ground }
        return nil
    }

    /// Кладёт частицу в сугроб, скатывая её вниз по склону. false — скатилась с края и падает дальше.
    private func settle(_ f: Flake, on s: Surface) -> Bool {
        var c = s.column(f.node.position.x)
        let n = s.heights.count
        for _ in 0..<20 {
            let h = s.heights[c]
            let left = c > 0 ? s.heights[c - 1] : -.infinity
            let right = c < n - 1 ? s.heights[c + 1] : -.infinity
            let goLeft = left < right || (left == right && Bool.random())
            let lower = goLeft ? left : right
            if h - lower <= columnWidth * (look.solidDrift ? 0.35 : 1) { break }
            if lower == -.infinity {
                f.node.position = CGPoint(x: goLeft ? s.x0 - 2 : s.x0 + s.width + 2, y: s.top + h)
                f.vx = goLeft ? -20 : 20
                f.vy = -10
                return false
            }
            c += goLeft ? -1 : 1
        }
        if s.heights[c] >= s.maxHeight {
            if s !== ground { return false }
            f.node.removeFromParent()
            return true
        }
        f.bump = f.node.size.height * look.bump
        s.heights[c] += f.bump
        f.node.position = CGPoint(x: s.x0 + (CGFloat(c) + 0.5) * columnWidth + CGFloat.random(in: -1.5...1.5),
                                  y: s.top + s.heights[c] - f.bump / 2)
        f.surface = s
        f.column = c
        f.vx = 0
        f.vy = 0
        f.node.isHidden = look.solidDrift
        s.dirty = true
        s.flakes.append(f)
        resting.append(f)
        return true
    }

    private func detach(_ f: Flake) {
        guard let s = f.surface else { return }
        s.heights[f.column] = max(0, s.heights[f.column] - f.bump)
        if let i = s.flakes.firstIndex(where: { $0 === f }) { s.flakes.remove(at: i) }
        f.surface = nil
        f.node.isHidden = false
        s.dirty = true
    }

    private func melt(_ f: Flake) {
        detach(f)
        f.node.run(.sequence([.fadeOut(withDuration: 1.5), .removeFromParent()]))
    }

    /// Сугроб (или один его столбик) осыпается вниз.
    private func drop(_ s: Surface, column: Int? = nil) {
        var kept: [Flake] = []
        for f in s.flakes {
            if let column, f.column != column {
                kept.append(f)
                continue
            }
            s.heights[f.column] = 0
            s.dirty = true
            f.surface = nil
            f.node.isHidden = false
            f.vx = CGFloat.random(in: -15...15)
            f.vy = -CGFloat.random(in: 10...40)
            falling.append(f)
        }
        s.flakes = kept
    }

    /// «Смести всё»: лежащее сдувает в одну сторону, и оно тает в воздухе.
    func clearAll() {
        beads.forEach { $0.node.removeFromParent() }; beads = []
        let dir: CGFloat = Bool.random() ? 1 : -1
        for s in [ground] + Array(windows.values) {
            for f in s.flakes {
                f.surface = nil
                f.node.isHidden = false
                f.node.run(.sequence([
                    .group([.moveBy(x: dir * CGFloat.random(in: 60...140), y: CGFloat.random(in: 8...35), duration: 1.8),
                            .fadeOut(withDuration: 1.8)]),
                    .removeFromParent(),
                ]))
            }
            s.flakes = []
            s.heights = Array(repeating: 0, count: s.heights.count)
            s.dirty = true
        }
        resting = []
    }

    private func pushByCursor(_ dt: CGFloat) {
        let g = NSEvent.mouseLocation
        let m = CGPoint(x: g.x - origin.x, y: g.y - origin.y)
        defer { lastMouse = m }
        guard let last = lastMouse, m.x > -50, m.x < size.width + 50, m.y > -50, m.y < size.height + 50 else { return }
        let vx = (m.x - last.x) / dt, vy = (m.y - last.y) / dt
        guard hypot(vx, vy) > 20 else { return }
        let r: CGFloat = 42
        let mouseX = min(max(vx, -800), 800)
        let mouseY = min(max(vy, -800), 800)
        var released = 0
        let releaseLimit = max(1, Int(90 * dt))

        for s in [ground] + Array(windows.values) {
            guard m.x > s.x0 - r, m.x < s.x0 + s.width + r, m.y > s.top - r, m.y < s.top + s.maxHeight + r else { continue }
            for f in s.flakes {
                let dx = f.node.position.x - m.x, dy = f.node.position.y - m.y
                let distance = hypot(dx, dy)
                guard distance < r, released < releaseLimit else { continue }
                let influence = pow(1 - distance / r, 2)
                guard CGFloat.random(in: 0...1) < influence else { continue }
                detach(f)
                f.vx = mouseX * 0.08 * influence + dx / r * 24 + CGFloat.random(in: -10...10)
                f.vy = CGFloat.random(in: 20...48) + max(0, mouseY) * 0.04 * influence
                falling.append(f)
                released += 1
            }
        }
        for f in falling {
            let dx = f.node.position.x - m.x, dy = f.node.position.y - m.y
            let d = hypot(dx, dy)
            guard d < r * 1.5, d > 0.1 else { continue }
            let influence = pow(1 - d / (r * 1.5), 2)
            f.vx += (dx / d * 160 + mouseX * 0.12) * influence * dt
            f.vy += (dy / d * 120 + mouseY * 0.08) * influence * dt
        }
    }

    /// Раз в 0,1 с: какие окна где стоят. Двинутое, закрытое или свёрнутое окно роняет свой сугроб.
    private func scanWindows() {
        guard onWindows,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
              as? [[String: Any]] else { return }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? size.height
        var all: [(id: Int, rect: CGRect)] = []
        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == 0, // обычные окна, без меню, Dock и нашего оверлея
                  let id = info[kCGWindowNumber as String] as? Int,
                  let dict = info[kCGWindowBounds as String] as? NSDictionary,
                  let b = CGRect(dictionaryRepresentation: dict as CFDictionary),
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.1,
                  b.width > 60, b.height > 40 else { continue }
            // У CGWindowList y вниз от верха главного экрана, у нас — вверх от низа этого экрана.
            all.append((id, CGRect(x: b.minX - origin.x, y: primaryHeight - b.maxY - origin.y,
                                   width: b.width, height: b.height)))
        }

        if all.count == lastWindowRects.count && zip(all, lastWindowRects).allSatisfy({ $0.id == $1.id && $0.rect == $1.rect }) { return }
        lastWindowRects = all
        var seen = Set<Int>()
        var newOrder: [(id: Int, rect: CGRect)] = []
        for (k, w) in all.enumerated() {
            let r = w.rect
            guard r.maxY > 0, r.maxY < size.height - 1, r.maxX > 0, r.minX < size.width else { continue }
            newOrder.append(w)
            seen.insert(w.id)
            if let old = windows[w.id], old.x0 != r.minX || old.top != r.maxY || old.width != r.width {
                drop(old)
                old.shape.removeFromParent()
                windows[w.id] = nil
            }
            let s: Surface
            if let existing = windows[w.id] {
                s = existing
            } else {
                s = Surface(x0: r.minX, top: r.maxY, width: r.width, maxHeight: 16)
                field.addChild(s.shape)
                windows[w.id] = s
            }
            let lineY = r.maxY + 1
            let front = all[..<k].map { $0.rect }.filter { $0.minY <= lineY && $0.maxY > lineY }
            for c in s.heights.indices {
                let p = CGPoint(x: s.x0 + (CGFloat(c) + 0.5) * columnWidth, y: lineY)
                let covered = front.contains { $0.contains(p) }
                if covered && s.heights[c] > 0 { drop(s, column: c) }
                s.visible[c] = !covered
            }
        }
        for (id, s) in windows where !seen.contains(id) {
            drop(s)
            s.shape.removeFromParent()
            windows[id] = nil
        }
        order = newOrder
    }
}

// MARK: - Прозрачное окно поверх экрана, сквозь которое проходят клики

final class Overlay {
    let window: NSWindow
    let scene: SnowScene

    init(screen: NSScreen) {
        window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.setFrame(screen.frame, display: false)
        let view = SKView(frame: CGRect(origin: .zero, size: screen.frame.size))
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = min(120, max(60, screen.maximumFramesPerSecond))
        scene = SnowScene(screen: screen)
        view.presentScene(scene)
        window.contentView = view
        window.orderFrontRegardless()
    }

    @MainActor
    func apply(_ d: UserDefaults, weather: WeatherStore) {
        scene.atmosphere.configure(city: nil,
            code: weather.current?.weather_code, size: scene.size,
            strength: d.double(forKey: "atmosphereStrength"), paused: d.bool(forKey: "paused"))
        let effect = weather.enabled ? weather.current?.effect : (Mode(rawValue: d.string(forKey: "mode") ?? "") ?? .snow)
        scene.setMode(effect ?? .snow)
        scene.field.isHidden = weather.enabled && effect == nil
        if d.bool(forKey: "paused") || d.object(forKey: "lightning") as? Bool == false { scene.hideLightning() }
        scene.isPaused = d.bool(forKey: "paused")
        scene.snowing = !d.bool(forKey: "paused") && effect != nil
        scene.intensity = d.double(forKey: "intensity")
        scene.speedFactor = max(d.double(forKey: "speed"), 0.1)
        scene.sizeFactor = d.double(forKey: "size")
        scene.field.alpha = d.double(forKey: "opacity")
        scene.onWindows = d.bool(forKey: "onWindows")
        scene.onGround = d.bool(forKey: "onGround")
        scene.cursor = d.bool(forKey: "cursor")
        scene.maxResting = Int(d.double(forKey: "drift"))

        let behind = d.bool(forKey: "behindWindows")
        window.level = behind ? NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1) : .statusBar
        var behavior: NSWindow.CollectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        if !behind && d.bool(forKey: "overFullScreen") { behavior.insert(.fullScreenAuxiliary) }
        window.collectionBehavior = behavior
        window.sharingType = d.bool(forKey: "hideInScreenshots") ? .none : .readOnly
    }
}

// MARK: - Окно настроек

struct SettingsView: View {
    @ObservedObject var weather: WeatherStore
    @AppStorage("mode") var mode = Mode.snow
    @AppStorage("paused") var paused = false
    @AppStorage("intensity") var intensity = 1.0
    @AppStorage("speed") var speed = 1.0
    @AppStorage("size") var size = 1.0
    @AppStorage("opacity") var opacity = 0.9
    @AppStorage("onWindows") var onWindows = true
    @AppStorage("onGround") var onGround = true
    @AppStorage("cursor") var cursor = true
    @AppStorage("drift") var drift = 2500.0
    @AppStorage("behindWindows") var behindWindows = false
    @AppStorage("overFullScreen") var overFullScreen = false
    @AppStorage("hideInScreenshots") var hideInScreenshots = true
    @AppStorage("showInMenuBar") var showInMenuBar = true
    @AppStorage("showInDock") var showInDock = false
    @AppStorage("appTheme") var theme = AppTheme.sage
    @AppStorage("lightning") var lightning = true
    @State var openAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Picker("Источник погоды", selection: Binding(get: { weather.enabled }, set: { weather.setEnabled($0) })) {
                    Text("Погода города").tag(true).disabled(weather.city == nil)
                    Text("Своя погода").tag(false)
                }.pickerStyle(.segmented)
                Picker("Эффект", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0) }
                }.disabled(weather.enabled)
                Toggle("Пауза", isOn: $paused)
            }
            Section("Оформление приложения") {
                Picker("Цветовая гамма", selection: $theme) {
                    ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                }
            }
            Section("Звуковой фон") { SoundControls(weather: weather) }
            Section("Гроза") {
                Toggle("Вспышки молнии", isOn: $lightning)
                Button("Проверить молнию") { NotificationCenter.default.post(name: .previewLightning, object: nil) }
                    .disabled(paused || !lightning || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
                Text("Одна вспышка без смены погоды. Между проверками — 3 секунды.").font(.caption).foregroundStyle(.secondary)
                Text("Редкие мягкие вспышки. При уменьшении движения в macOS молнии отключаются.").font(.caption).foregroundStyle(.secondary)
            }
            Section("Вид") {
                Slider(value: $intensity, in: 0.1...3) { Text("Количество") }
                Slider(value: $speed, in: 0.3...2.5) { Text("Скорость") }
                Slider(value: $size, in: 0.5...2.5) { Text("Размер") }
                Slider(value: $opacity, in: 0.1...1) { Text("Непрозрачность") }
            }
            Section("Сугробы") {
                Toggle("Копится на окнах", isOn: $onWindows)
                Toggle("Копится внизу экрана", isOn: $onGround)
                Toggle("Разлетается от курсора", isOn: $cursor)
                Slider(value: $drift, in: 300...6000) { Text("Сколько лежит") }
                HStack {
                    Spacer()
                    Button("Смести всё") { NotificationCenter.default.post(name: .clearAll, object: nil) }
                }
            }
            Section("Где показывать") {
                Toggle("Позади окон, на рабочем столе", isOn: $behindWindows)
                Toggle("Поверх полноэкранных приложений", isOn: $overFullScreen).disabled(behindWindows)
                Toggle("Прятать на скриншотах и при показе экрана", isOn: $hideInScreenshots)
            }
            Section {
                Toggle("Значок в строке меню", isOn: $showInMenuBar)
                Toggle("Значок в Dock", isOn: $showInDock)
                Toggle("Открывать при входе в систему", isOn: $openAtLogin)
                    .onChange(of: openAtLogin) { on in
                        let service = SMAppService.mainApp
                        _ = try? (on ? service.register() : service.unregister())
                        openAtLogin = service.status == .enabled
                    }
                Text("Если значки скрыты, запустите Sugrob ещё раз через Spotlight, Launchpad или Finder: откроется это окно.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Как найти приложение")
            }
            HStack {
                Spacer()
                Button("Выйти из Сугроба") { NSApp.terminate(nil) }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(theme.paper).tint(theme.ink).preferredColorScheme(.light)
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Приложение

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let weather = WeatherStore()
    let atmosphereSound = AtmosphereSound()
    let liveCamera = LiveCameraController()
    var overlays: [Overlay] = []
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var pauseItem: NSMenuItem!
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let d = UserDefaults.standard
        d.register(defaults: defaultSettings)
        if d.string(forKey: "appTheme") == "lavender" { d.set("blue", forKey: "appTheme") }


        statusItem.button?.image = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Сугроб")
        let menu = NSMenu()
        menu.addItem(withTitle: "Настройки…", action: #selector(showSettings), keyEquivalent: ",").target = self
        pauseItem = menu.addItem(withTitle: "Пауза", action: #selector(togglePause), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(withTitle: "Смести всё", action: #selector(clearAll), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Выйти", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu

        let center = NotificationCenter.default
        center.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.apply() }
        }
        center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.rebuildOverlays() }
        }
        center.addObserver(forName: .clearAll, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.clearAll() }
        }
        center.addObserver(forName: .lightningStrike, object: nil, queue: .main) { [weak self] note in
            guard let scene = note.object as? SnowScene else { return }
            Task { @MainActor in
                guard let self, self.overlays.first?.scene === scene else { return }
                self.atmosphereSound.strike()
            }
        }
        center.addObserver(forName: .previewLightning, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.overlays.forEach { $0.scene.previewLightning() } }
        }
        center.addObserver(forName: .previewAtmosphere, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.overlays.forEach { $0.scene.atmosphere.demonstrate() } }
        }
        center.addObserver(forName: .openLiveCamera, object: nil, queue: .main) { [weak self] note in
            guard let camera = note.object as? LiveCamera else { return }
            Task { @MainActor in self?.liveCamera.open(camera) }
        }
        weather.onChange = { [weak self] in self?.apply() }
        rebuildOverlays()
        weather.start()

        if !d.bool(forKey: "welcomed") {
            d.set(true, forKey: "welcomed")
            showSettings()
        }
    }

    // Повторный запуск уже работающего приложения или клик по значку в Dock.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    func rebuildOverlays() {
        overlays.forEach { $0.window.close() }
        overlays = NSScreen.screens.map { Overlay(screen: $0) }
        apply()
    }

    // Вызывается на каждое изменение UserDefaults, поэтому трогает только то, что поменялось.
    func apply() {
        let d = UserDefaults.standard
        overlays.forEach { $0.apply(d, weather: weather) }
        let soundMood = weather.city.map { CityMood(city: $0, code: weather.current?.weather_code) }
        let weatherSound = d.string(forKey: "soundSource") == "weather"
        let effect = weather.enabled ? weather.current?.effect : Mode(rawValue: d.string(forKey: "mode") ?? "snow")
        atmosphereSound.apply(enabled: (weatherSound || d.bool(forKey: "cityAtmosphere")) && d.bool(forKey: "atmosphereSound") && !d.bool(forKey: "paused"),
            mood: soundMood, volume: d.double(forKey: weatherSound ? "weatherVolume" : "atmosphereVolume"), florenceBells: d.bool(forKey: "florenceBells"), weatherSound: weatherSound, effect: effect, lightningEnabled: d.object(forKey: "lightning") as? Bool != false)
        pauseItem.state = d.bool(forKey: "paused") ? .on : .off

        let inMenuBar = d.bool(forKey: "showInMenuBar")
        if statusItem.isVisible != inMenuBar { statusItem.isVisible = inMenuBar }

        let policy: NSApplication.ActivationPolicy = d.bool(forKey: "showInDock") ? .regular : .accessory
        if NSApp.activationPolicy() != policy {
            NSApp.setActivationPolicy(policy)
            // После смены режима macOS может увести окно настроек на задний план — возвращаем.
            if settingsWindow?.isVisible == true { showSettings() }
        }
    }

    @objc func togglePause() {
        let d = UserDefaults.standard
        d.set(!d.bool(forKey: "paused"), forKey: "paused")
    }

    @objc func clearAll() {
        overlays.forEach { $0.scene.clearAll() }
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: DashboardView(weather: weather)))
            w.title = "Сугроб"
            w.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            w.setContentSize(NSSize(width: 1040, height: 820))
            w.minSize = NSSize(width: 850, height: 680)
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow!.makeKeyAndOrderFront(nil)
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
withExtendedLifetime(delegate) { app.run() }
