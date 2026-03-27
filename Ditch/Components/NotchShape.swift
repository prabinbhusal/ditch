import SwiftUI

// Rounded rect where top and bottom corners animate independently
struct NotchShape: Shape {
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topCornerRadius, bottomCornerRadius) }
        set {
            topCornerRadius = newValue.first
            bottomCornerRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tr = topCornerRadius
        let br = bottomCornerRadius

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + tr, y: rect.minY + tr),
                          control: CGPoint(x: rect.minX + tr, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + tr, y: rect.maxY - br))
        path.addQuadCurve(to: CGPoint(x: rect.minX + tr + br, y: rect.maxY),
                          control: CGPoint(x: rect.minX + tr, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - tr - br, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - tr, y: rect.maxY - br),
                          control: CGPoint(x: rect.maxX - tr, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY + tr))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.maxX - tr, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))

        return path
    }
}
