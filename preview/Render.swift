import AppKit

@main struct Render {
    static func main() throws {
        let output = CommandLine.arguments[1]
        let dates = ["2026-10-15T13:00:00Z", "2026-07-15T16:00:00Z", "2026-05-15T10:00:00Z", "2026-06-15T20:30:00Z", "2026-04-15T14:00:00Z", "2026-09-15T15:00:00Z", "2026-11-21T14:00:00Z"]
        let size = CGSize(width: 1560, height: 1250)
        let image = AtmosphereArt.image(size: size) { c in
            c.setFillColor(NSColor(calibratedWhite: 0.08, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
            func text(_ value: String, x: CGFloat, y: CGFloat, size: CGFloat, color: NSColor) {
                (value as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: NSFont.systemFont(ofSize: size), .foregroundColor: color])
            }
            text("СУГРОБ  /  Побыть в другом городе", x: 28, y: 1197, size: 26, color: .white)
            text("Художественные образы · разные сезоны и местное время · примеры без осадков", x: 28, y: 1168, size: 15, color: .lightGray)
            for (index, portrait) in CityPortrait.destinations.enumerated() {
                let x = CGFloat(index == 6 ? 1 : index % 3) * 510 + 25
                let y = CGFloat(807 - (index / 3) * 372)
                let panel = CGSize(width: 490, height: 285)
                let date = ISO8601DateFormatter().date(from: dates[index])!
                let mood = CityMood(city: portrait.city, date: date, code: 0)
                c.saveGState()
                c.translateBy(x: x, y: y)
                c.setFillColor(NSColor(calibratedRed: 0.13, green: 0.16, blue: 0.21, alpha: 1).cgColor)
                c.fill(CGRect(origin: .zero, size: panel))
                // A quiet sample desktop beneath the actual transparent artwork.
                c.setFillColor(NSColor(calibratedWhite: 0.13, alpha: 1).cgColor)
                c.fill(CGRect(x: 48, y: 80, width: 250, height: 142))
                c.setStrokeColor(NSColor(calibratedWhite: 0.32, alpha: 1).cgColor)
                c.stroke(CGRect(x: 48, y: 80, width: 250, height: 142))
                for row in 0..<5 {
                    c.setFillColor(NSColor(calibratedWhite: 0.26, alpha: 1).cgColor)
                    c.fill(CGRect(x: 66, y: CGFloat(178 - row * 17), width: CGFloat(80 + row % 3 * 42), height: 3))
                }
                c.draw(AtmosphereArt.backdrop(mood, size: panel), in: CGRect(origin: .zero, size: panel))
                let tint: NSColor = mood.particle == .leaf ? .systemOrange : (mood.particle == .olive ? .systemGreen : mood.tint)
                let particle = AtmosphereArt.particle(mood.particle, tint: tint)
                for i in 0..<(mood.particle == .gull ? 1 : 4) {
                    c.setAlpha(0.55)
                    c.draw(particle, in: CGRect(x: CGFloat(80 + i * 96), y: CGFloat(250 - (i * 53) % 185), width: mood.particle == .gull ? 34 : 19, height: mood.particle == .gull ? 34 : 19))
                }
                c.restoreGState()
                text(portrait.city.name, x: x, y: y + 300, size: 22, color: .white)
                text("\(mood.season.rawValue) · \(mood.light.rawValue) · \(CityMood.localTime(date, city: portrait.city))", x: x, y: y - 26, size: 14, color: .lightGray)
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
        try data.write(to: URL(fileURLWithPath: output))
    }
}
