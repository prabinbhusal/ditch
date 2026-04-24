import AppKit

enum NotchDropState: Equatable {
    case idle
    case dragActive
    case dragInside
    case scanning(ScanningAppInfo)
    case dropped(DroppedAppInfo)
    case cleaning(DroppedAppInfo)
    case cleaned(CleanResult)
    case blocked(BlockedAppInfo)
}

struct ScanningAppInfo: Equatable, @unchecked Sendable {
    let name: String
    let icon: NSImage

    static func == (lhs: ScanningAppInfo, rhs: ScanningAppInfo) -> Bool {
        lhs.name == rhs.name
    }
}

struct BlockedAppInfo: Equatable, @unchecked Sendable {
    let name: String
    let icon: NSImage
    let reason: String

    static func == (lhs: BlockedAppInfo, rhs: BlockedAppInfo) -> Bool {
        lhs.name == rhs.name && lhs.reason == rhs.reason
    }
}

struct DroppedAppInfo: Equatable, @unchecked Sendable {
    let name: String
    let url: URL
    let icon: NSImage
    let appSize: String
    let filesFound: Int
    let totalSize: String
    let scanResult: AppScanResult

    static func == (lhs: DroppedAppInfo, rhs: DroppedAppInfo) -> Bool {
        lhs.url == rhs.url
    }
}

struct CleanResult: Equatable, @unchecked Sendable {
    let appName: String
    let icon: NSImage
    let removed: Int
    let failed: Int
    let totalSize: String
    let failedFiles: [FailedFileEntry]

    static func == (lhs: CleanResult, rhs: CleanResult) -> Bool {
        lhs.appName == rhs.appName && lhs.removed == rhs.removed
    }
}

struct NotchAnimState: Equatable, Sendable {
    var width: CGFloat
    var topCornerRadius: CGFloat
    var bottomCornerRadius: CGFloat
}
