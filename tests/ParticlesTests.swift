import AppKit
import SpriteKit

@main struct ParticlesTests {
    static func main() {
        _ = NSApplication.shared
        guard let screen = NSScreen.main else { fatalError("A display is required for particle tests") }
        let scene = SnowScene(screen: screen)
        scene.onWindows = false
        scene.cursor = false
        func particles() -> [Flake] {
            Mirror(reflecting: scene).children.first { $0.label == "falling" }!.value as! [Flake]
        }
        scene.setMode(.snow)
        scene.update(1)
        precondition(!particles().isEmpty)
        scene.setMode(.rain)
        precondition(particles().isEmpty, "Old snow must not inherit rain physics")
        scene.update(1.02)
        let rain = particles()
        precondition(!rain.isEmpty)
        precondition(rain.allSatisfy { abs($0.node.zRotation + 0.04) < 0.001 })
        scene.setMode(.rain)
        precondition(particles().first === rain.first, "Same effect must retain continuity")
        let oldY = rain[0].node.position.y
        scene.update(1.02 + 1.0/120)
        precondition(rain[0].node.position.y < oldY)
        let pausedY = rain[0].node.position.y
        scene.isPaused = true
        scene.update(1.05)
        precondition(rain[0].node.position.y == pausedY, "Pause must stop existing particles")
        scene.isPaused = false
        scene.setMode(.leaves)
        precondition(particles().isEmpty)
        print("PASS: clean transitions, aligned rain, same-effect continuity, 120 Hz movement")
    }
}
