// Appended to the scene source by run-particles.sh to exercise private simulation state.
extension SnowScene {
    func checkWindowCrossing() {
        let surface = Surface(x0: 0, top: 200, width: 1000, maxHeight: 16)
        windows = [1: surface]
        order = [(1, CGRect(x: 0, y: 0, width: 1000, height: 200))]
        for kind in [Mode.snow, .rain, .storm, .petals, .leaves] {
            setMode(kind)
            falling = []
            resting = []
            for collects in [false, true] {
                let f = Flake(node: SKSpriteNode(color: .white, size: CGSize(width: 3, height: 3)))
                f.node.position = CGPoint(x: 500, y: 201)
                f.vy = -100
                f.collectsOnWindows = collects
                falling.append(f)
                field.addChild(f.node)
            }
            fall(0.05)
            precondition(falling.count == ((kind == .rain || kind == .storm) ? 2 : 1))
            precondition(falling.allSatisfy { $0.node.position.y < 200 })
            precondition(resting.count == ((kind == .rain || kind == .storm) ? 0 : 1))
        }
        setMode(.storm)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            stormWait = 0
            updateLightning(0.05)
            precondition(lightning != nil)
            updateLightning(0.7)
            precondition(lightning == nil && stormWait > 10)
        }
        setMode(.clouds)
        precondition(falling.count == 4)
        let x = falling[0].node.position.x, y = falling[0].node.position.y
        fall(0.05)
        precondition(falling[0].node.position.x > x && falling[0].node.position.y == y)
        precondition(resting.isEmpty)
        setMode(.snow)
        precondition(falling.isEmpty)
        print("PASS: snow, petals and leaves cross window edges; rain never settles")
    }
}
SnowScene(screen: NSScreen.main!).checkWindowCrossing()
