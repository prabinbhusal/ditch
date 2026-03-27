import AppKit

struct NotchInfo {
    let hasNotch: Bool
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let notchX: CGFloat
    let notchY: CGFloat
    let screenFrame: NSRect
}

// Figures out where the notch is (or fakes one on older Macs)
enum NotchDetector {

    static func detect() -> NotchInfo {
        guard let screen = NSScreen.main else {
            return fallback(for: .zero)
        }

        let frame = screen.frame

        if #available(macOS 12.0, *),
           let topLeft = screen.auxiliaryTopLeftArea,
           let topRight = screen.auxiliaryTopRightArea,
           topLeft != .zero, topRight != .zero {

            let width = frame.width - topLeft.width - topRight.width
            let height = max(topLeft.height, topRight.height)

            return NotchInfo(
                hasNotch: true,
                notchWidth: width,
                notchHeight: height,
                notchX: topLeft.maxX,
                notchY: frame.maxY - height,
                screenFrame: frame
            )
        }

        return fallback(for: frame)
    }

    private static func fallback(for frame: NSRect) -> NotchInfo {
        let menuBarHeight = frame.maxY - (NSScreen.main?.visibleFrame.maxY ?? frame.maxY)
        return NotchInfo(
            hasNotch: menuBarHeight >= 33,
            notchWidth: 180,
            notchHeight: 32,
            notchX: frame.midX - 90,
            notchY: frame.maxY - 32,
            screenFrame: frame
        )
    }
}
