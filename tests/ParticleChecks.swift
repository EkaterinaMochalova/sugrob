// Appended to the scene source by run-particles.sh to exercise private simulation state.
extension SnowScene {
    func checkWindowCrossing() {
        let surface = Surface(x0: 0, top: 200, width: 1000, maxHeight: 16)
        windows = [1: surface]
        order = [(1, CGRect(x: 0, y: 0, width: 1000, height: 200))]
        for kind in [Mode.snow, .rain] {
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
            precondition(falling.count == (kind == .snow ? 1 : 2))
            precondition(falling.allSatisfy { $0.node.position.y < 200 })
            precondition(resting.count == (kind == .snow ? 1 : 0))
        }
        print("PASS: snow foreground and rain cross window edges; only background snow settles")
    }
}
SnowScene(screen: NSScreen.main!).checkWindowCrossing()
