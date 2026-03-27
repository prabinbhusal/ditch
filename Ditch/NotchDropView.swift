import SwiftUI
import AppKit

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

extension AnyTransition {
    static var notchTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.92, anchor: .top)
                .combined(with: .opacity)
                .animation(.spring(response: 0.3, dampingFraction: 0.82)),
            removal: .scale(scale: 0.92, anchor: .top)
                .combined(with: .opacity)
                .animation(.spring(response: 0.25, dampingFraction: 0.9))
        )
    }
}

struct NotchDropView: View {
    @Binding var dropState: NotchDropState
    let notchInfo: NotchInfo
    let onAppDropped: (URL) -> Void
    var onConfirm: (() -> Void)?
    var onCancel: (() -> Void)?

    @State private var contentHeight: CGFloat = 0
    @State private var bounceScale: CGFloat = 1.0

    private var notchTotalHeight: CGFloat {
        isExpanded ? max(notchInfo.notchHeight, contentHeight) : 0
    }

    private var state: NotchAnimState {
        let w = notchInfo.notchWidth
        switch dropState {
        case .idle:
            return NotchAnimState(width: w, topCornerRadius: 6, bottomCornerRadius: 14)
        case .dragActive, .dragInside:
            return NotchAnimState(width: w + Constants.Layout.expandedWidthIncrease, topCornerRadius: 12, bottomCornerRadius: 18)
        case .scanning, .dropped, .cleaning, .cleaned:
            return NotchAnimState(width: w + Constants.Layout.expandedWidthIncrease, topCornerRadius: 12, bottomCornerRadius: 22)
        }
    }

    private var isExpanded: Bool { dropState != .idle }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                Rectangle().fill(Color.black).padding(-50)
            }
            .mask(NotchShape(topCornerRadius: state.topCornerRadius,
                             bottomCornerRadius: state.bottomCornerRadius))
            .frame(width: state.width, height: notchTotalHeight)

            VStack(spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: "xmark.bin.fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Ditch")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)
                .opacity(isExpanded ? 1 : 0)
                .scaleEffect(isExpanded ? 1 : 0.8, anchor: .top)

                ZStack {
                    switch dropState {
                    case .dragActive, .dragInside:
                        dropZone.transition(.notchTransition)
                    case .scanning(let info):
                        scanningContent(info: info).transition(.notchTransition)
                    case .dropped(let info):
                        droppedContent(info: info).transition(.notchTransition)
                    case .cleaning(let info):
                        cleaningContent(info: info).transition(.notchTransition)
                    case .cleaned(let result):
                        cleanedContent(result: result).transition(.notchTransition)
                    default:
                        Color.clear.frame(height: 0)
                    }
                }
                .padding(.top, max(0, notchInfo.notchHeight - 12))
            }
            .padding(.horizontal, Constants.Layout.contentPadding)
            .padding(.bottom, isExpanded ? 14 : 0)
            .frame(width: state.width)
            .fixedSize(horizontal: false, vertical: true)
            .background(GeometryReader { geo in
                Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
            })
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        .scaleEffect(x: bounceScale, y: 2 - bounceScale, anchor: .top)
        .animation(.bouncy(duration: 0.4), value: dropState)
        .onChange(of: dropState) { newState in
            if case .dropped = newState {
                withAnimation(.easeIn(duration: 0.08)) { bounceScale = 1.03 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { bounceScale = 1.0 }
                }
            }
        }
    }

    @ViewBuilder
    private var dropZone: some View {
        let isInside = dropState == .dragInside

        ZStack {
            RoundedRectangle(cornerRadius: state.bottomCornerRadius - 4, style: .continuous)
                .fill(isInside ? Color.red.opacity(0.10) : Color.white.opacity(0.04))

            RoundedRectangle(cornerRadius: state.bottomCornerRadius - 4, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7, 5]))
                .foregroundColor(isInside ? .red.opacity(0.6) : .white.opacity(0.12))

            VStack(spacing: 8) {
                PulsingDropIcon(isInside: isInside)
                Text(isInside ? "Release to ditch" : "Drop app here")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(isInside ? .white.opacity(0.85) : .white.opacity(0.3))
            }
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.Layout.dropZoneHeight)
    }

    @ViewBuilder
    private func droppedContent(info: DroppedAppInfo?) -> some View {
        let info = info ?? placeholderInfo

        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(nsImage: info.icon)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(info.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(info.filesFound) files · \(info.totalSize)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
            }
            .padding(.bottom, 10)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    let files = info.scanResult.relatedFiles
                    ForEach(Array(files.enumerated()), id: \.offset) { index, file in
                        StaggeredFileRow(
                            content: AnyView(fileRow(file: file, isLast: index == files.count - 1)),
                            index: index
                        )
                    }
                }
            }
            .frame(maxHeight: Constants.Layout.fileRowHeight * Constants.Layout.fileListMaxRows)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.07), lineWidth: 0.5)
            )
            .padding(.bottom, 8)

            HStack(spacing: 10) {
                Button(action: { onCancel?() }) {
                    Text("Cancel")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(LiquidGlassButtonStyle(tint: .white, capsule: true))

                Button(action: { onConfirm?() }) {
                    Text("Remove")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                }
                .buttonStyle(LiquidGlassButtonStyle(tint: .red, capsule: true, filled: true))
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func fileRow(file: RelatedFile, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            FileRowButton(
                file: file,
                icon: NSWorkspace.shared.icon(forFile: file.url.path),
                path: shortenedPath(file.url)
            )
            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 0.5)
                    .padding(.leading, 40)
            }
        }
    }

    private func shortenedPath(_ url: URL) -> String {
        let path = url.deletingLastPathComponent().path
        let home = NSHomeDirectory()
        return path.hasPrefix(home) ? "~" + path.dropFirst(home.count) : path
    }

    @ViewBuilder
    private func scanningContent(info: ScanningAppInfo?) -> some View {
        let info = info ?? ScanningAppInfo(name: " ", icon: NSImage())

        HStack(spacing: 10) {
            Image(nsImage: info.icon)
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .opacity(0.7)

            VStack(alignment: .leading, spacing: 2) {
                Text("Scanning \(info.name)...")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                HStack(spacing: 6) {
                    Text("Finding related files")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                    ProgressView()
                        .controlSize(.mini)
                        .tint(.white.opacity(0.5))
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func cleaningContent(info: DroppedAppInfo?) -> some View {
        let info = info ?? placeholderInfo

        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(nsImage: info.icon)
                    .resizable()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .opacity(0.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.black.opacity(0.3))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text("Removing \(info.name)...")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                    Text("Cleaning \(info.filesFound) files · \(info.totalSize)")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.35))
                }
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(LinearGradient(
                            colors: [.red.opacity(0.6), .red.opacity(0.8)],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * 0.6)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: true)
                }
            }
            .frame(height: 3)
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func cleanedContent(result: CleanResult?) -> some View {
        let result = result ?? CleanResult(appName: " ", icon: NSImage(), removed: 0, failed: 0, totalSize: " ", failedFiles: [])

        VStack(spacing: 10) {
            HStack(spacing: 10) {
                AnimatedCheckmark()

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(result.appName) removed")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text("\(result.removed) files cleaned · \(result.totalSize) freed")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.45))
                }
                Spacer()
            }

            if result.failed > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.yellow.opacity(0.8))
                        Text("\(result.failed) file\(result.failed == 1 ? "" : "s") couldn't be removed")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundColor(.yellow.opacity(0.7))
                    }

                    ForEach(Array(result.failedFiles.enumerated()), id: \.offset) { _, entry in
                        HStack(spacing: 4) {
                            Text(entry.path)
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.5))
                                .lineLimit(1)
                            Text("— \(entry.reason)")
                                .font(.system(size: 9, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.3))
                                .lineLimit(1)
                        }
                        .padding(.leading, 15)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var placeholderInfo: DroppedAppInfo {
        DroppedAppInfo(
            name: " ", url: URL(fileURLWithPath: "/"), icon: NSImage(),
            appSize: " ", filesFound: 0, totalSize: " ",
            scanResult: AppScanResult(appURL: URL(fileURLWithPath: "/"), bundleIdentifier: nil, relatedFiles: [], totalSize: 0)
        )
    }
}

// Handles the actual drag-and-drop at the AppKit level
final class NotchDropNSView: NSView {
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?
    var onDrop: ((URL) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard hasAppBundle(in: sender) else { return [] }
        onDragEntered?()
        return .move
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        onDragExited?()
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        hasAppBundle(in: sender) ? .move : []
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        hasAppBundle(in: sender)
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let url = appURL(from: sender) else { return false }
        onDrop?(url)
        return true
    }

    private func hasAppBundle(in info: NSDraggingInfo) -> Bool {
        appURL(from: info) != nil
    }

    private func appURL(from info: NSDraggingInfo) -> URL? {
        guard let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] else { return nil }
        let appDirs = Constants.applicationDirectories
        for url in urls {
            if url.pathExtension == "app" && appDirs.contains(where: { url.path.hasPrefix($0) }) {
                return url
            }
        }
        return nil
    }
}
