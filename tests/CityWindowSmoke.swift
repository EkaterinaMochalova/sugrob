import AppKit
import AVFoundation

@main struct CityWindowSmoke {
    @MainActor final class Runner {
        let controller = CityWindowController()
        var before: Double = 0
        func content() -> CityWindowContent? {
            NSApp.windows.first(where: { $0.isVisible && $0.title.contains("Окно в город") })?.contentView as? CityWindowContent
        }
        func fail(_ reason: String) { print("FAIL: \(reason)"); fflush(stdout); exit(1) }
        func start() {
            print("START: native Rome view"); fflush(stdout)
            controller.open(CityPortrait.rome.city)
            DispatchQueue.main.asyncAfter(deadline: .now()+5) { self.loaded() }
        }
        func loaded() {
            guard let view = content(), view.hasLoadedMedia else { fail("video not ready"); return }
            before = view.player.currentTime().seconds
            print("PASS: video ready"); fflush(stdout)
            DispatchQueue.main.asyncAfter(deadline: .now()+2) {
                guard let view = self.content(), view.player.currentTime().seconds > self.before else { self.fail("playback did not advance"); return }
                print("PASS: playback advances"); fflush(stdout)
                view.window?.close()
                self.controller.open(CityPortrait.petersburg.city)
                guard let photo = self.content(), photo.isPhoto, photo.hasLoadedMedia else { self.fail("photo not loaded"); return }
                photo.window?.close()
                self.controller.open(CityPortrait.rome.city)
                DispatchQueue.main.asyncAfter(deadline: .now()+3) {
                    guard self.content()?.hasLoadedMedia == true else { self.fail("reopen failed"); return }
                    self.content()?.window?.close()
                    print("PASS: photo, close and video reopen"); fflush(stdout)
                    NSApp.terminate(nil)
                }
            }
        }
    }
    static func main() {
        let app = NSApplication.shared
        let runner = MainActor.assumeIsolated { Runner() }
        app.setActivationPolicy(.accessory)
        DispatchQueue.main.asyncAfter(deadline: .now()+1) { MainActor.assumeIsolated { runner.start() } }
        DispatchQueue.main.asyncAfter(deadline: .now()+45) { print("FAIL: timeout"); fflush(stdout); exit(2) }
        withExtendedLifetime(runner) { app.run() }
    }
}
