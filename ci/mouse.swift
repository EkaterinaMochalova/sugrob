// Проводит курсором слева направо по высоте y (координаты CG: от верха экрана) или вдоль низа экрана.
// CGWarpMouseCursorPosition не требует разрешений.
import CoreGraphics
import Foundation

let bounds = CGDisplayBounds(CGMainDisplayID())
let y = CommandLine.arguments[1] == "bottom" ? bounds.maxY - 8 : Double(CommandLine.arguments[1])!
for i in 0...150 {
    CGWarpMouseCursorPosition(CGPoint(x: bounds.minX + 50 + Double(i) * (bounds.width - 100) / 150, y: y))
    usleep(15_000)
}
