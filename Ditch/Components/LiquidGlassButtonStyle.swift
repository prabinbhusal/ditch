import SwiftUI

struct LiquidGlassButtonStyle: ButtonStyle {
    var tint: Color = .white
    var capsule: Bool = false
    var filled: Bool = false

    private var cornerRadius: CGFloat { capsule ? 100 : 10 }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .background(
                ZStack {
                    if filled {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(LinearGradient(
                                stops: [
                                    .init(color: tint.opacity(pressed ? 0.6 : 0.75), location: 0),
                                    .init(color: tint.opacity(pressed ? 0.5 : 0.65), location: 1),
                                ],
                                startPoint: .top, endPoint: .bottom
                            ))

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.18), location: 0),
                                    .init(color: .clear, location: 0.45),
                                ],
                                startPoint: .top, endPoint: .bottom
                            ))

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.25), location: 0),
                                    .init(color: tint.opacity(0.3), location: 0.5),
                                    .init(color: tint.opacity(0.1), location: 1),
                                ],
                                startPoint: .top, endPoint: .bottom
                            ), lineWidth: 0.5)
                    } else {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(pressed ? 0.25 : 0.12))

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.28), location: 0),
                                    .init(color: .white.opacity(0.08), location: 0.35),
                                    .init(color: .clear, location: 0.55),
                                ],
                                startPoint: .top, endPoint: .bottom
                            ))

                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(0.45), location: 0),
                                    .init(color: .white.opacity(0.12), location: 0.4),
                                    .init(color: .white.opacity(0.06), location: 1),
                                ],
                                startPoint: .top, endPoint: .bottom
                            ), lineWidth: 0.5)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(pressed ? 0.97 : 1.0)
            .opacity(pressed ? 0.85 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: pressed)
    }
}
