import SwiftUI

struct AnimatedCheckmark: View {
    @State private var trimEnd: CGFloat = 0
    @State private var glowOpacity: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(
                    colors: [.green.opacity(0.3), .green.opacity(0.0)],
                    center: .center, startRadius: 0, endRadius: 22
                ))
                .frame(width: 44, height: 44)
                .opacity(glowOpacity)

            Circle()
                .fill(RadialGradient(
                    colors: [.green.opacity(0.25), .green.opacity(0.05)],
                    center: .center, startRadius: 0, endRadius: 18
                ))
                .frame(width: 36, height: 36)

            CheckmarkPath()
                .trim(from: 0, to: trimEnd)
                .stroke(.green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .frame(width: 16, height: 16)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.15)) { trimEnd = 1.0 }
            withAnimation(.easeInOut(duration: 0.6).delay(0.3)) { glowOpacity = 1.0 }
            withAnimation(.easeInOut(duration: 0.8).delay(0.8)) { glowOpacity = 0.4 }
        }
    }
}

private struct CheckmarkPath: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.1, y: rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.width * 0.38, y: rect.height * 0.8))
        path.addLine(to: CGPoint(x: rect.width * 0.9, y: rect.height * 0.15))
        return path
    }
}
