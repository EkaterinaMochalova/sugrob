import AppKit
import WebKit

struct LiveCamera: Decodable {
    let id: String
    let title: String
    let provider: String
    let embed: URL?
    let source: URL
    let watch: URL
    static let all: [LiveCamera] = {
        guard let url = Bundle.main.url(forResource: "live-cameras", withExtension: "json"),
              let data = try? Data(contentsOf: url), let cameras = try? JSONDecoder().decode([LiveCamera].self, from: data) else { return [] }
        return cameras
    }()
    static func forCity(_ city: WeatherCity) -> LiveCamera? { all.first { $0.id == CityPortrait.matching(city).rawValue } }
}

extension Notification.Name { static let openLiveCamera = Notification.Name("SugrobOpenLiveCamera") }

// Retained by the app delegate, independent of SwiftUI view updates.
@MainActor
final class LiveCameraController: NSObject, WKNavigationDelegate, NSWindowDelegate {
    private var window: NSWindow?
    private var web: WKWebView?
    private var camera: LiveCamera?
    private var timer: Timer?
    private var lastTime: Double = -1
    private var generation = 0
    private let status = NSTextField(labelWithString: "Подключаем камеру…")

    func open(_ camera: LiveCamera) {
        guard let url = camera.embed else { NSWorkspace.shared.open(camera.watch); return }
        if self.camera?.id == camera.id, let window, window.isVisible {
            window.makeKeyAndOrderFront(nil); return
        }
        dispose()
        self.camera = camera
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = self
        web = view
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 610))
        view.frame = NSRect(x: 0, y: 62, width: 960, height: 548)
        view.autoresizingMask = [.width, .height]
        host.addSubview(view)
        status.stringValue = "Подключаем камеру…"
        status.frame = NSRect(x: 16, y: 35, width: 900, height: 18)
        status.autoresizingMask = [.width]
        status.font = .systemFont(ofSize: 12)
        host.addSubview(status)
        let source = NSButton(title: camera.provider + " ↗", target: self, action: #selector(openSource))
        source.frame = NSRect(x: 12, y: 5, width: 230, height: 26)
        source.bezelStyle = .rounded
        host.addSubview(source)
        let retry = NSButton(title: "Обновить", target: self, action: #selector(retry))
        retry.frame = NSRect(x: 620, y: 5, width: 110, height: 26)
        retry.autoresizingMask = [.minXMargin]; retry.bezelStyle = .rounded; host.addSubview(retry)
        let browser = NSButton(title: "Открыть в браузере ↗", target: self, action: #selector(openBrowser))
        browser.frame = NSRect(x: 740, y: 5, width: 205, height: 26)
        browser.autoresizingMask = [.minXMargin]; browser.bezelStyle = .rounded; host.addSubview(browser)
        let win = NSWindow(contentRect: host.frame, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        win.title = camera.title
        win.contentView = host
        win.minSize = NSSize(width: 620, height: 420)
        win.isReleasedWhenClosed = false
        win.delegate = self
        window = win
        load(url)
        win.center(); win.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkPlayback() }
        }
    }
    private func load(_ url: URL) {
        lastTime = -1
        status.stringValue = "Подключаем камеру…"
        var request = URLRequest(url: url)
        request.setValue("https://local.sugrob", forHTTPHeaderField: "Referer")
        web?.load(request)
    }
    @objc private func retry() { if let url = camera?.embed { load(url) } }
    @objc private func openSource() { if let camera { NSWorkspace.shared.open(camera.source) } }
    @objc private func openBrowser() { if let camera { NSWorkspace.shared.open(camera.watch) } }
    private func checkPlayback() {
        let token = generation
        web?.evaluateJavaScript("(()=>{const v=document.querySelector('video');return v?{t:v.currentTime,paused:v.paused,ready:v.readyState,error:!!v.error}:null})()") { [weak self] value, _ in
            guard let self, self.generation == token else { return }
            guard let v = value as? [String: Any], let t = v["t"] as? Double else {
                self.status.stringValue = "Ожидаем видео · если эфир не появился, откройте источник в браузере"
                return
            }
            if v["error"] as? Bool == true { self.status.stringValue = "Видео недоступно · обновите или откройте в браузере" }
            else if v["paused"] as? Bool == true { self.status.stringValue = "Пауза · нажмите ▶ в плеере" }
            else if t > self.lastTime && self.lastTime >= 0 { self.status.stringValue = "● Видео воспроизводится · звук — в плеере" }
            else { self.status.stringValue = "Буферизация · ждём следующий кадр" }
            self.lastTime = t
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        status.stringValue = "Не удалось подключиться · обновите или откройте в браузере"
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            if ["https", "http"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { status.stringValue = "Плеер остановился · нажмите «Обновить»" }
    private func dispose() {
        generation += 1
        timer?.invalidate(); timer = nil
        web?.stopLoading(); web?.loadHTMLString("", baseURL: nil); web?.removeFromSuperview(); web = nil
        window?.orderOut(nil); window = nil; camera = nil
    }
    func windowWillClose(_ notification: Notification) { dispose() }
}
