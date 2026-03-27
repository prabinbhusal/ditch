import AppKit

// Sits over the notch area, invisible until a drag starts
final class NotchWindow: NSWindow {

    init(notchInfo: NotchInfo) {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let canvasWidth = notchInfo.notchWidth + Constants.Layout.canvasMargin
        let canvasHeight = notchInfo.notchHeight + Constants.Layout.canvasMargin
        let centerX = notchInfo.notchX + notchInfo.notchWidth / 2

        super.init(
            contentRect: NSRect(
                x: centerX - canvasWidth / 2,
                y: screen.frame.maxY - canvasHeight,
                width: canvasWidth,
                height: canvasHeight
            ),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        alphaValue = 0
    }

    func fadeIn(duration: TimeInterval = 0.15) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            animator().alphaValue = 1.0
        }
    }

    func fadeOut(duration: TimeInterval = 0.4, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = duration
            animator().alphaValue = 0.0
        }, completionHandler: {
            completion?()
        })
    }
}
