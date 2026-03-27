import SwiftUI

struct PulsingDropIcon: View {
    let isInside: Bool
    @State private var isPulsing = false

    var body: some View {
        ZStack {
            if !isInside {
                Circle()
                    .fill(.white.opacity(0.04))
                    .frame(width: 40, height: 40)
                    .scaleEffect(isPulsing ? 1.3 : 1.0)
                    .opacity(isPulsing ? 0 : 0.6)
            }

            Image(systemName: isInside ? "xmark.bin.fill" : "arrow.down.app.fill")
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .foregroundStyle(
                    isInside
                        ? AnyShapeStyle(.red.opacity(0.9))
                        : AnyShapeStyle(.white.opacity(0.35))
                )
                .frame(width: 30, height: 30)
        }
        .frame(width: 44, height: 44)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
