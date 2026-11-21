import AppKit
import AVFoundation

@MainActor
final class CityWindowContent: NSView {
    let city: WeatherCity
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private let picture = CALayer()
    private let tint = CALayer()
    private let video = AVPlayerLayer()
    private let timeLabel = NSTextField(labelWithString: "")
    private let sourceLabel = NSTextField(labelWithString: "Записанный вид · Автоматический свет")
    private let pauseButton = NSButton(title: "Пауза", target: nil, action: nil)
    private var timer: Timer?
    private(set) var isPhoto = false
    var hasLoadedMedia: Bool { isPhoto ? picture.contents != nil : player.currentItem?.status == .readyToPlay }

    init(city: WeatherCity, url: URL) {
        self.city = city
        super.init(frame: NSRect(x: 0, y: 0, width: 370, height: 720))
        wantsLayer = true
        layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        video.backgroundColor = NSColor.black.cgColor
        picture.backgroundColor = NSColor.black.cgColor
        picture.contentsGravity = .resizeAspect
        video.videoGravity = .resizeAspect
        layer?.addSublayer(picture)
        layer?.addSublayer(video)
        layer?.addSublayer(tint)
        for label in [timeLabel, sourceLabel] { label.font = .systemFont(ofSize: 11); label.textColor = .secondaryLabelColor; addSubview(label) }
        addSubview(pauseButton)
        pauseButton.target = self
        pauseButton.action = #selector(togglePlayback)
        pauseButton.bezelStyle = .rounded
        isPhoto = url.pathExtension.lowercased() == "jpg"
        if isPhoto {
            picture.contents = NSImage(contentsOf: url)?.cgImage(forProposedRect: nil, context: nil, hints: nil)
            video.isHidden = true
            pauseButton.isHidden = true
            sourceLabel.stringValue = "Фото · Автоматический свет"
        } else {
            player.isMuted = true
            video.player = player
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
            player.play()
            if CityPortrait.matching(city) == .tokyo { sourceLabel.stringValue = "Запись · Осенний сад · Авто" }
        }
        refreshLight()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshLight() }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() {
        super.layout()
        let area = CGRect(x: 9, y: 64, width: max(1, bounds.width - 18), height: max(1, bounds.height - 73))
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for item in [picture, video, tint] { item.frame = area; item.cornerRadius = 8; item.masksToBounds = true }
        CATransaction.commit()
        timeLabel.frame = NSRect(x: 14, y: 36, width: max(1, bounds.width - 28), height: 18)
        sourceLabel.frame = NSRect(x: 14, y: 12, width: max(1, bounds.width - 105), height: 18)
        pauseButton.frame = NSRect(x: bounds.width - 88, y: 7, width: 80, height: 28)
    }
    @objc private func togglePlayback() {
        if player.rate == 0 { player.play(); pauseButton.title = "Пауза" }
        else { player.pause(); pauseButton.title = "Продолжить" }
    }
    private func refreshLight() {
        let date = Date(), mood = CityMood(city: city, date: date)
        timeLabel.stringValue = "\(city.name) · \(CityMood.localTime(date, city: city)) · \(mood.light.rawValue)"
        let color: NSColor
        switch mood.light {
        case .night: color = NSColor(calibratedRed: 0.025, green: 0.06, blue: 0.14, alpha: 0.55)
        case .dusk: color = NSColor(calibratedRed: 0.55, green: 0.25, blue: 0.06, alpha: 0.14)
        case .dawn: color = NSColor(calibratedRed: 0.45, green: 0.48, blue: 0.62, alpha: 0.16)
        case .whiteNight: color = NSColor(calibratedRed: 0.28, green: 0.34, blue: 0.5, alpha: 0.2)
        case .day: color = .clear
        }
        CATransaction.begin(); CATransaction.setAnimationDuration(2)
        tint.backgroundColor = color.cgColor
        CATransaction.commit()
    }
    func stop() {
        timer?.invalidate(); timer = nil
        player.pause(); looper?.disableLooping(); looper = nil
        player.removeAllItems(); video.player = nil
    }
}

@MainActor
final class CityWindowController: NSObject, NSWindowDelegate {
    static let supported: Set<CityPortrait> = [.florence, .rome, .moscow, .tokyo, .petersburg, .athens]
    private var windows: [CityPortrait: NSWindow] = [:]
    func open(_ city: WeatherCity) {
        let id = CityPortrait.matching(city)
        guard Self.supported.contains(id) else { return }
        if let window = windows[id] { window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        guard let resources = Bundle.main.resourceURL else { return }
        let file = resources.appendingPathComponent("CityMedia").appendingPathComponent(id.rawValue + (id == .petersburg ? ".jpg" : ".mp4"))
        guard FileManager.default.fileExists(atPath: file.path) else {
            let alert = NSAlert(); alert.messageText = "Не найден файл вида города"
            alert.informativeText = "Распакуйте приложение целиком из архива и запустите его снова."
            alert.runModal(); return
        }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 370, height: 720), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Окно в город · \(city.name)"
        window.minSize = NSSize(width: 280, height: 430)
        window.contentView = CityWindowContent(city: city, url: file)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center(); windows[id] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        (window.contentView as? CityWindowContent)?.stop()
        if let key = windows.first(where: { $0.value === window })?.key { windows.removeValue(forKey: key) }
    }
}
