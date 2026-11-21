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
    "showInMenuBar": true, "showInDock": false, "cityAtmosphere": false, "atmosphereStrength": 0.65, "atmosphereSound": false, "atmosphereVolume": 0.25,
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
let leafTexture = sprite(40, 40) { r in
    NSImage(systemSymbolName: "leaf.fill", accessibilityDescription: nil)?
        .withSymbolConfiguration(.init(pointSize: 32, weight: .regular))?.draw(in: r)
    NSColor.white.set()
    r.fill(using: .sourceIn)
}
let petalTexture = sprite(16, 26) { r in
    NSColor.white.set()
    NSBezierPath(ovalIn: r.insetBy(dx: 1, dy: 1)).fill()
}
let dropTexture = sprite(3, 40) { r in
    NSGradient(starting: NSColor.white.withAlphaComponent(0), ending: .white)!.draw(in: r, angle: -90)
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

func makeLook(_ mode: Mode) -> Look {
    switch mode {
    case .snow:
        // Подогнано по записи Snowhush: много мелких тусклых снежинок, частое мелкое покачивание, сплошной сугроб.
        return Look(texture: flakeTexture, aspect: 1, colors: [.white], alpha: 0.35...0.95, rate: 45, fall: 90,
                    drag: 1.5, sway: 25, spin: 0, size: 1.5...4, bump: 0.5, settles: true, solidDrift: true)
    case .leaves:
        return Look(texture: leafTexture, aspect: 1, colors: [.systemOrange, .systemRed, .systemYellow, .brown],
                    alpha: 0.85...1, rate: 8, fall: 80, drag: 1.2, sway: 45, spin: 2, size: 14...24, bump: 0.15,
                    settles: true, solidDrift: false)
    case .rain:
        return Look(texture: dropTexture, aspect: 3.0 / 40, colors: [.white], alpha: 0.3...0.6, rate: 150, fall: 900,
                    drag: 8, sway: 0, spin: 0, size: 18...32, bump: 0, settles: false, solidDrift: false)
    case .petals:
        return Look(texture: petalTexture, aspect: 16.0 / 26,
                    colors: [NSColor(red: 1, green: 0.78, blue: 0.85, alpha: 1), NSColor(red: 1, green: 0.9, blue: 0.93, alpha: 1)],
                    alpha: 0.85...1, rate: 10, fall: 70, drag: 1.3, sway: 35, spin: 2.5, size: 9...15, bump: 0.15,
                    settles: true, solidDrift: false)
    }
}

// MARK: - Симуляция

let columnWidth: CGFloat = 4

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
        let last = heights.count - 1
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x0, y: top))
        for i in heights.indices {
            let h = (heights[max(i - 1, 0)] + 2 * heights[i] + heights[min(i + 1, last)]) / 4
            path.addLine(to: CGPoint(x: x0 + (CGFloat(i) + 0.5) * columnWidth, y: top + h))
        }
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
        }
    }
    let atmosphere = AtmosphereNode()
    let field = SKNode() // все частицы; его прозрачность — настройка «Непрозрачность»

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
        look = makeLook(newMode)
        if !first { clearAll() }
    }

    override func update(_ currentTime: TimeInterval) {
        let raw = CGFloat(min(currentTime - lastTime, 0.05))
        lastTime = currentTime
        guard raw > 0 else { return }
        atmosphere.tick(TimeInterval(raw))
        let dt = raw * speedFactor
        clock += dt

        if currentTime - lastScan > 0.1 {
            lastScan = currentTime
            scanWindows()
        }
        if snowing && falling.count < 5000 {
            spawnDebt += look.rate * intensity * size.width / 1440 * raw
            while spawnDebt >= 1 {
                spawnDebt -= 1
                spawn()
            }
        }
        if cursor { pushByCursor(raw) } else { lastMouse = nil }
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
        let h = (look.size.lowerBound + (look.size.upperBound - look.size.lowerBound) * depth) * sizeFactor
        let node = SKSpriteNode(texture: look.texture, color: look.colors.randomElement()!,
                                size: CGSize(width: h * look.aspect, height: h))
        node.colorBlendFactor = 1
        node.alpha = look.alpha.lowerBound + (look.alpha.upperBound - look.alpha.lowerBound) * depth
        node.position = CGPoint(x: .random(in: -40...(size.width + 40)), y: size.height + h)
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
            // vx — толчки и ветер, они гаснут; покачивание добавляется отдельно, чтобы сопротивление его не гасило.
            f.vx -= f.vx * k
            f.vy += (-look.fall * f.weight - f.vy) * k
            let sway = sin(clock * f.freq + f.phase) * look.sway * f.weight
            let np = CGPoint(x: p.x + (f.vx + sway) * dt, y: p.y + f.vy * dt)
            f.node.position = np
            f.node.zRotation += f.spin * dt

            let out = np.y < -30 || np.x < -80 || np.x > size.width + 80 || np.y > size.height + 400
            if !out, mode == .rain, let s = landing(x: np.x, y: np.y, prevY: p.y), CGFloat.random(in: 0...1) < 0.12 {
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
            } else if look.settles, f.vy < 0, let s = landing(x: np.x, y: np.y, prevY: p.y) {
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
            guard mode == .rain, valid, s.visible[s.column(bead.x)], bead.age < 4 else {
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
            if h - lower <= columnWidth { break }
            if lower == -.infinity {
                f.node.position = CGPoint(x: goLeft ? s.x0 - 2 : s.x0 + s.width + 2, y: s.top + h)
                f.vx = goLeft ? -20 : 20
                f.vy = -10
                return false
            }
            c += goLeft ? -1 : 1
        }
        if s.heights[c] >= s.maxHeight {
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
                    .group([.moveBy(x: dir * CGFloat.random(in: 150...400), y: CGFloat.random(in: 20...120), duration: 1.2),
                            .fadeOut(withDuration: 1.2)]),
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
        let r: CGFloat = 30

        for s in [ground] + Array(windows.values) {
            guard m.x > s.x0 - r, m.x < s.x0 + s.width + r, m.y > s.top - r, m.y < s.top + s.maxHeight + r else { continue }
            for f in s.flakes {
                let dx = f.node.position.x - m.x, dy = f.node.position.y - m.y
                guard hypot(dx, dy) < r else { continue }
                detach(f)
                f.vx = min(max(vx * 0.3, -500), 500) + dx / r * 120 + CGFloat.random(in: -40...40)
                f.vy = CGFloat.random(in: 80...240) + min(max(vy, 0) * 0.3, 300)
                falling.append(f)
            }
        }
        for f in falling {
            let dx = f.node.position.x - m.x, dy = f.node.position.y - m.y
            let d = hypot(dx, dy)
            guard d < r * 1.5, d > 0.1 else { continue }
            f.vx += dx / d * 1500 * dt + vx * 0.03
            f.vy += dy / d * 1500 * dt + vy * 0.03
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
        view.preferredFramesPerSecond = 60
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
    @State var openAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Picker("Что падает", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0) }
                }.disabled(weather.enabled)
                Toggle("Пауза", isOn: $paused)
            }
            WeatherSettingsView(weather: weather)
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
        .frame(width: 460, height: 620) // у сгруппированной формы нет своей высоты: без этого окно сжимается до заголовка
    }
}

// MARK: - Приложение

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let weather = WeatherStore()
    let atmosphereSound = AtmosphereSound()
    var overlays: [Overlay] = []
    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    var pauseItem: NSMenuItem!
    var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let d = UserDefaults.standard
        d.register(defaults: defaultSettings)


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
        center.addObserver(forName: .previewAtmosphere, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.overlays.forEach { $0.scene.atmosphere.demonstrate() } }
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
        atmosphereSound.apply(enabled: weather.enabled && d.bool(forKey: "cityAtmosphere") && d.bool(forKey: "atmosphereSound") && !d.bool(forKey: "paused"),
            mood: soundMood, volume: d.double(forKey: "atmosphereVolume"))
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
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(weather: weather)))
            w.title = "Сугроб"
            w.styleMask = [.titled, .closable, .miniaturizable]
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
