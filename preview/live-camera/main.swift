import AppKit
import WebKit

final class CameraPreview: NSObject, WKNavigationDelegate, NSWindowDelegate {
    var window: NSWindow?
    var web: WKWebView?
    func open() {
        print("Creating camera window"); fflush(stdout)
        let config = WKWebViewConfiguration()
        config.mediaTypesRequiringUserActionForPlayback = []
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 960, height: 580), configuration: config)
        web = view
        view.navigationDelegate = self
        let win = NSWindow(contentRect: view.frame, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        win.title = "Флоренция · Live · webcamfirenze"
        let host = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 620))
        view.frame = NSRect(x: 0, y: 40, width: 960, height: 580)
        view.autoresizingMask = [.width, .height]
        host.addSubview(view)
        let source = NSButton(title: "webcamfirenze · CC BY 3.0", target: self, action: #selector(openSource))
        source.frame = NSRect(x: 12, y: 8, width: 220, height: 24)
        source.bezelStyle = .rounded
        host.addSubview(source)
        let browser = NSButton(title: "Открыть в браузере", target: self, action: #selector(openBrowser))
        browser.frame = NSRect(x: 750, y: 8, width: 198, height: 24)
        browser.autoresizingMask = [.minXMargin]
        browser.bezelStyle = .rounded
        host.addSubview(browser)
        win.contentView = host
        win.minSize = NSSize(width: 480, height: 320)
        win.isReleasedWhenClosed = false
        win.delegate = self
        window = win
        var request = URLRequest(url: URL(string: "https://www.youtube.com/embed/qBtMuRnf7BY?autoplay=1&mute=1&playsinline=1")!)
        request.setValue("https://local.sugrob.livepreview", forHTTPHeaderField: "Referer")
        view.load(request)
        win.center(); win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        print("Camera window created"); fflush(stdout)
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Player page loaded"); fflush(stdout)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("Load error: \(error.localizedDescription)"); fflush(stdout)
    }
    @objc func openSource() { NSWorkspace.shared.open(URL(string: "https://webcamfirenze.altervista.org/")!) }
    @objc func openBrowser() { NSWorkspace.shared.open(URL(string: "https://www.youtube.com/watch?v=qBtMuRnf7BY")!) }
    func windowWillClose(_ notification: Notification) { NSApp.terminate(nil) }
    func check() {
        guard let web else { print("FAIL: web view not created"); fflush(stdout); exit(1) }
        web.evaluateJavaScript("JSON.stringify({text:document.body.innerText,video:Array.from(document.querySelectorAll('video')).map(v=>({width:v.videoWidth,time:v.currentTime,paused:v.paused,error:v.error?.code}))})") { value,error in
            print("Player status: \(String(describing:value)) / \(String(describing:error))"); fflush(stdout)
            NSApp.terminate(nil)
        }
    }
}
let app = NSApplication.shared
let preview = CameraPreview()
app.setActivationPolicy(.regular)
DispatchQueue.main.asyncAfter(deadline: .now()+1) { preview.open() }
if CommandLine.arguments.contains("--smoke-test") {
    DispatchQueue.main.asyncAfter(deadline: .now()+30) { preview.check() }
    DispatchQueue.main.asyncAfter(deadline: .now()+40) { print("FAIL: preview timeout");fflush(stdout);exit(2) }
}
withExtendedLifetime(preview) { app.run() }
