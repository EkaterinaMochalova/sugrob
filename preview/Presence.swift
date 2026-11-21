import AppKit
import ImageIO
import UniformTypeIdentifiers
@main struct PresencePreview {
    static func main() throws {
        let out = URL(fileURLWithPath: CommandLine.arguments[1])
        let width = 1000, height = 620
        let branch = PresenceAssets.image("maple")!
        let fps = 10
        let destination = CGImageDestinationCreateWithURL(out as CFURL, UTType.gif.identifier as CFString, 250, nil)!
        CGImageDestinationSetProperties(destination, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        for frame in 0..<250 {
            let t = Double(frame) / Double(fps)
            let image = AtmosphereArt.image(size: CGSize(width: width, height: height)) { c in
                c.setFillColor(NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.20, alpha: 1).cgColor)
                c.fill(CGRect(x: 0, y: 0, width: width, height: height))
                NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
                func text(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ color: NSColor) {
                    (s as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font:NSFont.systemFont(ofSize:size),.foregroundColor:color])
                }
                text("СУГРОБ  /  Движение из-за края", 38, 558, 22, .white)
                text("Демонстрация · Токио осенью · звук выключен", 38, 529, 14, .lightGray)
                c.setFillColor(NSColor(calibratedWhite: 0.94, alpha: 1).cgColor)
                c.fill(CGRect(x: 65, y: 115, width: 500, height: 340))
                text("Рабочее окно", 90, 414, 18, .darkGray)
                c.setFillColor(NSColor(calibratedWhite:0.80,alpha:1).cgColor)
                for i in 0..<8 { c.fill(CGRect(x: 90, y: 375-i*25, width: 220+i%3*50, height: 3)) }
                let clamp: (Double)->Double = { min(1,max(0,$0)) }
                let ease: (Double)->Double = { $0*$0*(3-2*$0) }
                let visible = ease(clamp(t/5)) * (1-ease(clamp((t-17)/6)))
                let w=460.0, h=w*Double(branch.height)/Double(branch.width)
                c.saveGState();c.setAlpha(visible * 0.86)
                c.translateBy(x: Double(width)+w*(0.10+(1-visible)*0.82), y:Double(height)*0.72)
                c.rotate(by:sin(t/3.2)*0.03)
                c.draw(branch,in:CGRect(x:-w,y:-h/2,width:w,height:h));c.restoreGState()
                text(t<5 ? "Порыв ветра…" : t<17 ? "Мягкое покачивание" : "Ветка уходит за край", 38, 42, 14, .lightGray)
                NSGraphicsContext.restoreGraphicsState()
            }
            if frame == 90 {
                let png = NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!
                try png.write(to:out.deletingPathExtension().appendingPathExtension("png"))
            }
            CGImageDestinationAddImage(destination,image,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/Double(fps)]] as CFDictionary)
        }
        precondition(CGImageDestinationFinalize(destination))
    }
}
