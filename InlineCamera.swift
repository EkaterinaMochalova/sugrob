import SwiftUI
import WebKit

// One player lives in the dashboard. Resizing never replaces its WebKit session.
@MainActor
final class InlineCameraSession: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var status = "Подключаем камеру…"
    weak var web: WKWebView?
    private var camera: LiveCamera?
    private var loadedKey: String?
    private var timer: Timer?
    private var lastTime: Double = -1
    private var generation = 0
    var expanded = false
    var collapse: (() -> Void)?
    private var keys: Any?

    func attach(_ web: WKWebView) {
        self.web = web
        web.navigationDelegate = self
        keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.expanded, event.keyCode == 53, event.window === self.web?.window else { return event }
            self.collapse?(); return nil
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }
    func select(_ camera: LiveCamera) {
        guard self.camera?.key != camera.key else { return }
        self.camera = camera
        load()
    }
    func reload() { load() }
    private func load() {
        guard let web, let url = camera?.embed else { return }
        generation += 1; lastTime = -1; loadedKey = camera?.key
        status = "Подключаем камеру…"
        web.stopLoading()
        web.alphaValue = 0
        var request = URLRequest(url: url)
        request.setValue("https://local.sugrob", forHTTPHeaderField: "Referer")
        web.load(request)
    }
    private func tick() {
        guard let web else { return }
        guard let window = web.window, window.isVisible, !window.isMiniaturized else {
            if loadedKey != nil {
                generation += 1; loadedKey = nil
                web.stopLoading(); web.loadHTMLString("", baseURL: nil)
            }
            return
        }
        if loadedKey == nil { load(); return }
        let token = generation
        web.evaluateJavaScript("(()=>{const v=document.querySelector('video'),p=document.getElementById('movie_player');let r;try{r=p?.getPlayerResponse?.()}catch{}const e=document.querySelector('.ytp-error-content-wrap');const message=e&&e.getClientRects().length?e.textContent.trim().slice(0,240):'';const live=r?.microformat?.playerMicroformatRenderer?.liveBroadcastDetails?.isLiveNow;const type=live===true?'Прямой эфир':r?.videoDetails?.isLiveContent===false?'Видео':live===false?'Запись эфира':'Видео · тип эфира не подтверждён';return message?{t:0,error:true,message}:v?{t:v.currentTime,paused:v.paused,error:!!v.error,type}:null})()") { [weak self] value, _ in
            guard let self, token == self.generation else { return }
            guard let v = value as? [String: Any], let t = v["t"] as? Double else {
                self.status = "Ожидаем плеер · запуск — кнопкой ▶"; return
            }
            if v["error"] as? Bool == true { self.status = "Видео недоступно: " + (v["message"] as? String ?? "попробуйте обновить") }
            else if v["paused"] as? Bool == true { self.status = "Пауза · нажмите ▶ в плеере" }
            else if t > self.lastTime && self.lastTime >= 0 { self.status = "● " + (v["type"] as? String ?? "Видео") + " · воспроизводится" }
            else { self.status = "Буферизация…" }
            self.lastTime = t
        }
    }
    func detach() {
        generation += 1
        timer?.invalidate(); timer = nil
        if let keys { NSEvent.removeMonitor(keys) }; keys = nil
        web?.stopLoading(); web?.loadHTMLString("", baseURL: nil); web?.navigationDelegate = nil
        web = nil; camera = nil; loadedKey = nil
    }
    private func reveal(_ web: WKWebView) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.55
            web.animator().alphaValue = 1
        }
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { reveal(webView) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code != NSURLErrorCancelled { reveal(webView); status = "Не удалось подключиться · попробуйте обновить" }
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { status = "Плеер остановился · нажмите «Обновить»" }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if action.navigationType == .linkActivated, let url = action.request.url {
            if ["http", "https"].contains(url.scheme ?? "") { NSWorkspace.shared.open(url) }
            decisionHandler(.cancel)
        } else { decisionHandler(.allow) }
    }
}

struct InlineCameraView: NSViewRepresentable {
    let camera: LiveCamera
    let session: InlineCameraSession
    let expanded: Bool
    let collapse: () -> Void
    func makeCoordinator() -> InlineCameraSession { session }
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        let web = WKWebView(frame: .zero, configuration: config)
        session.attach(web)
        return web
    }
    func updateNSView(_ view: WKWebView, context: Context) {
        session.expanded = expanded; session.collapse = collapse
        // Publishing during a SwiftUI update would cause a rendering cycle.
        DispatchQueue.main.async { [weak session] in session?.select(camera) }
    }
    static func dismantleNSView(_ view: WKWebView, coordinator: InlineCameraSession) { coordinator.detach() }
}
