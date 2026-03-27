import Foundation
import CoreGraphics

enum Constants {

    // How much wider/taller the notch panel grows when expanded
    enum Layout {
        static let expandedWidthIncrease: CGFloat = 240
        static let canvasMargin: CGFloat = 420
        static let dropZoneHeight: CGFloat = 90
        static let fileListMaxRows: CGFloat = 8
        static let fileRowHeight: CGFloat = 34
        static let contentPadding: CGFloat = 26
        static let zoneExtraHeight: CGFloat = 150
        static let zoneExtraWidth: CGFloat = 280
    }

    static let applicationDirectories: [String] = [
        "/Applications",
        NSHomeDirectory() + "/Applications",
        "/System/Applications"
    ]


    enum LaunchAgent {
        static let label = "com.ditch.app"
        static let plistPath = NSHomeDirectory() + "/Library/LaunchAgents/com.ditch.app.plist"
        static let launchAgentsDir = NSHomeDirectory() + "/Library/LaunchAgents"
    }
}
