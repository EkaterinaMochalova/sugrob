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
            let sample = makeLightning()
            precondition(sample.path!.boundingBox.height >= size.height * 0.95)
            precondition(sample.children.count == 27)
            stormWait = 0
            updateLightning(0.05)
            precondition(lightning != nil)
            updateLightning(0.7)
            precondition(lightning == nil && stormWait > 10)
        }
        setMode(.clouds)
        precondition(falling.count == 5)
        precondition(falling.allSatisfy { $0.node.position.y >= size.height - min(150, size.height * 0.16) && $0.node.position.y <= size.height - min(150, size.height * 0.08) && $0.node.size.height <= 168 && $0.node.alpha <= 0.36 })
        let x = falling[0].node.position.x, y = falling[0].node.position.y
        fall(0.05)
        precondition(falling[0].node.position.x > x && falling[0].node.position.y == y)
        precondition(resting.isEmpty)
        setMode(.snow)
        precondition(falling.isEmpty)
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            field.isHidden = true
            previewLightning()
            precondition(childNode(withName: "lightningPreview") != nil)
            previewLightning()
            precondition(children.filter { $0.name == "lightningPreview" }.count == 1)
            hideLightning()
            precondition(childNode(withName: "lightningPreview") == nil)
        }
        print("PASS: snow, petals and leaves cross window edges; rain never settles")
    }
}
SnowScene(screen: NSScreen.main!).checkWindowCrossing()

let light = SunlightNode()
light.configure(active: false, city: nil, size: CGSize(width: 1440, height: 900), dust: true, strength: 0.9)
precondition(light.isHidden)
light.preview(); light.tick(8)
precondition(!light.isHidden)
if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { precondition(light.children.suffix(32).contains { $0.alpha > 0 }) }
light.tick(13); precondition(light.isHidden)
light.configure(active: false, city: nil, size: CGSize(width: 1440, height: 900), dust: false, strength: 0.9)
light.preview(); light.tick(8)
precondition(!light.isHidden && light.children.suffix(32).allSatisfy { $0.alpha == 0 })
print("PASS: sunlight preview expires and dust respects toggle")

extension SnowScene {
 func checkCloudDrag() {
  let previous = UserDefaults.standard.object(forKey: "cloudLevels")
  defer { if let previous { UserDefaults.standard.set(previous, forKey: "cloudLevels") } else { UserDefaults.standard.removeObject(forKey: "cloudLevels") } }
  setMode(.clouds); dragClouds = true
  let f = falling[2]
  precondition(cloudAt(f.node.position) != nil)
  draggedCloud = f; cloudOffset = CGPoint(x: 5, y: 5)
  moveCloud(CGPoint(x: 805, y: size.height * 0.5 + 5))
  precondition(f.node.position.x == 800)
  finishCloudDrag()
  let variant = f.node.userData!["cloudVariant"] as! Int
  cloudIndex = variant; spawn()
  precondition(abs(falling.last!.node.position.y - size.height * 0.5) < 0.01)
  dragClouds = false; precondition(cloudAt(f.node.position) == nil)
  resetCloudHeights(); precondition(UserDefaults.standard.object(forKey: "cloudLevels") == nil)
  print("PASS: cloud dragging preserves offsets, persists height and resets")
 }
}
SnowScene(screen: NSScreen.main!).checkCloudDrag()
