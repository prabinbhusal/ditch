import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private var notchWindow: NotchWindow!
    private var notchInfo: NotchInfo!
    private var dropState = NotchDropState.idle
    private var dropNSView: NotchDropNSView!
    private var notchZoneView: NotchDropNSView!
    private var hostingView: NSHostingView<AnyView>!
    private var currentScanResult: AppScanResult?
    private var dismissTask: Task<Void, Never>?
    private var dragMonitor: Any?
    private var dragEndMonitor: Any?
    private var launchAtLoginItem: NSMenuItem!
    private var launchAtLoginToggle: NSSwitch!
    private var hotKeyMonitor: Any?



    func applicationDidFinishLaunching(_ notification: Notification) {
        notchInfo = NotchDetector.detect()
        setupStatusItem()
        setupNotchWindow()
        setupDragMonitoring()
        setupGlobalHotKey()
    }


    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "xmark.bin.fill", accessibilityDescription: "Ditch")

        let menu = NSMenu()
        menu.delegate = self

        let title = NSMenuItem(title: "Ditch", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        launchAtLoginItem = NSMenuItem()
        let toggleView = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 30))

        let label = NSTextField(labelWithString: "Launch at Login")
        label.font = NSFont.systemFont(ofSize: 13)
        label.textColor = .labelColor
        label.frame = NSRect(x: 14, y: 5, width: 140, height: 20)
        toggleView.addSubview(label)

        launchAtLoginToggle = NSSwitch()
        launchAtLoginToggle.controlSize = .mini
        launchAtLoginToggle.frame = NSRect(x: 160, y: 3, width: 36, height: 24)
        launchAtLoginToggle.target = self
        launchAtLoginToggle.action = #selector(toggleLaunchAtLogin)
        toggleView.addSubview(launchAtLoginToggle)

        launchAtLoginItem.view = toggleView
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())

        let openTrash = NSMenuItem(title: "Open Trash", action: #selector(openTrash), keyEquivalent: "")
        openTrash.target = self
        menu.addItem(openTrash)

        let about = NSMenuItem(title: "About Ditch…", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Ditch", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }


    @objc private func toggleLaunchAtLogin(_ sender: NSSwitch) {
        let enable = sender.state == .on

        // SMAppService is the clean way, but needs proper signing
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            do {
                if enable {
                    try service.register()
                } else {
                    try service.unregister()
                }
                return
            } catch {
                NSLog("SMAppService failed: \(error.localizedDescription), falling back to LaunchAgent")
            }
        }

        // Fallback: drop a LaunchAgent plist manually
        let launchAgentsDir = Constants.LaunchAgent.launchAgentsDir
        let plistPath = Constants.LaunchAgent.plistPath
        let fm = FileManager.default

        if enable {
            let appPath = Bundle.main.bundlePath
            let plist: [String: Any] = [
                "Label": Constants.LaunchAgent.label,
                "ProgramArguments": [appPath + "/Contents/MacOS/Ditch"],
                "RunAtLoad": true,
                "KeepAlive": false
            ]

            // Create LaunchAgents directory if needed
            if !fm.fileExists(atPath: launchAgentsDir) {
                try? fm.createDirectory(atPath: launchAgentsDir, withIntermediateDirectories: true)
            }

            (plist as NSDictionary).write(toFile: plistPath, atomically: true)
        } else {
            try? fm.removeItem(atPath: plistPath)
        }
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status == .enabled {
                return true
            }
        }
        // Check LaunchAgent fallback
        return FileManager.default.fileExists(atPath: Constants.LaunchAgent.plistPath)
    }



    @objc private func openTrash() {
        let trashURLs = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask)
        if let trashURL = trashURLs.first {
            NSWorkspace.shared.open(trashURL)
        }
    }

    @objc private func showAbout() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

        let alert = NSAlert()
        alert.messageText = "Ditch"
        alert.informativeText = "Version \(version) (\(build))\n\nDrag. Drop. Ditch.\nA lightweight app cleaner that lives in your MacBook's notch.\n\n© 2026 Ditch"
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "xmark.bin.fill", accessibilityDescription: "Ditch")
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }


    private func setupDragMonitoring() {
        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if self.dropState == .idle && !self.notchWindow.isVisible {
                    if self.isDraggingApp() {
                        self.showWindow()
                    }
                }
            }
        }

        dragEndMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            guard let self else { return }
            DispatchQueue.main.async {
                if self.dropState == .idle || self.dropState == .dragActive {
                    self.updateDropState(.idle)
                    self.hideWindow()
                }
            }
        }
    }

    private func isDraggingApp() -> Bool {
        let pasteboard = NSPasteboard(name: .drag)
        
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty else {
            return false
        }
        
        let appDirs = Constants.applicationDirectories
        
        for url in urls {
            if url.pathExtension == "app" && appDirs.contains(where: { url.path.hasPrefix($0) }) {
                return true
            }
        }
        
        return false
    }


    private func setupGlobalHotKey() {
        // ⌘⇧D toggles the drop zone
        hotKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if flags == [.command, .shift] && event.charactersIgnoringModifiers == "d" {
                DispatchQueue.main.async {
                    if self.notchWindow.isVisible && (self.dropState == .idle || self.dropState == .dragActive) {
                        self.updateDropState(.idle)
                        self.hideWindow()
                    } else if !self.notchWindow.isVisible {
                        self.showWindow()
                        self.updateDropState(.dragActive)
                    }
                }
            }
        }
    }


    private func setupNotchWindow() {
        notchWindow = NotchWindow(notchInfo: notchInfo)
        let bounds = notchWindow.contentView!.bounds

        dropNSView = NotchDropNSView(frame: bounds)
        dropNSView.autoresizingMask = [.width, .height]
        dropNSView.onDragEntered = { [weak self] in
            guard let self, self.dropState == .idle else { return }
            self.updateDropState(.dragActive)
        }
        dropNSView.onDragExited = { [weak self] in
            guard let self, self.dropState == .dragActive else { return }
            self.updateDropState(.idle)
        }
        dropNSView.onDrop = { [weak self] url in
            guard let self, self.dropState == .dragInside else { return }
            self.handleAppDrop(url: url)
        }

        let zoneHeight = notchInfo.notchHeight + Constants.Layout.zoneExtraHeight
        let zoneWidth = notchInfo.notchWidth + Constants.Layout.zoneExtraWidth
        let zoneX = (bounds.width - zoneWidth) / 2
        let zoneY = bounds.height - zoneHeight
        notchZoneView = NotchDropNSView(frame: NSRect(x: zoneX, y: zoneY, width: zoneWidth, height: zoneHeight))
        notchZoneView.onDragEntered = { [weak self] in self?.updateDropState(.dragInside) }
        notchZoneView.onDragExited = { [weak self] in self?.updateDropState(.dragActive) }
        notchZoneView.onDrop = { [weak self] url in self?.handleAppDrop(url: url) }

        updateHostingView()

        notchWindow.contentView?.addSubview(hostingView)
        notchWindow.contentView?.addSubview(dropNSView)
        notchWindow.contentView?.addSubview(notchZoneView)
        notchWindow.orderOut(nil)
    }


    private func showWindow() {
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        notchWindow.alphaValue = 0
        NSAnimationContext.endGrouping()

        notchWindow.ignoresMouseEvents = false
        notchWindow.orderFrontRegardless()
        notchWindow.fadeIn()
    }

    private func hideWindow() {
        notchWindow.fadeOut { [weak self] in
            guard let self, self.notchWindow.alphaValue < 0.01 else { return }
            self.notchWindow.orderOut(nil)
            self.notchWindow.ignoresMouseEvents = true
        }
    }


    private func updateHostingView() {
        let view = NotchDropView(
            dropState: .constant(dropState),
            notchInfo: notchInfo,
            onAppDropped: { [weak self] url in self?.handleAppDrop(url: url) },
            onConfirm: { [weak self] in self?.performUninstall() },
            onCancel: { [weak self] in self?.cancelDrop() }
        )

        if hostingView == nil {
            hostingView = NSHostingView(rootView: AnyView(view))
            hostingView.frame = notchWindow.contentView!.bounds
            hostingView.autoresizingMask = [.width, .height]
            if #available(macOS 13.3, *) { hostingView.safeAreaRegions = [] }
        } else {
            hostingView.rootView = AnyView(view)
        }
    }


    private func updateDropState(_ newState: NotchDropState) {
        dropState = newState
        updateHostingView()

        let interactive: Bool = {
            switch newState {
            case .scanning, .dropped, .cleaning, .cleaned: return true
            default: return false
            }
        }()
        dropNSView.isHidden = interactive
        notchZoneView.isHidden = interactive

        notchWindow.level = .statusBar
        notchWindow.ignoresMouseEvents = {
            if case .scanning = newState { return true }
            return false
        }()

        switch newState {
        case .dragInside:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        case .dropped:
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        case .cleaned:
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        default: break
        }

        if case .cleaned = newState {
            NSSound(named: "Purr")?.play()
        }
    }


    private func handleAppDrop(url: URL) {
        let name = url.deletingPathExtension().lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: url.path)

        // System apps are SIP-protected and can't be removed
        if url.path.hasPrefix("/System/") {
            updateDropState(.blocked(BlockedAppInfo(name: name, icon: icon, reason: "System apps can't be uninstalled")))
            autoDismiss(after: 2.0)
            return
        }

        updateDropState(.scanning(ScanningAppInfo(name: name, icon: icon)))

        Task.detached(priority: .userInitiated) { [weak self] in
            let result = AppCleaner.scan(appURL: url)

            await MainActor.run {
                guard let self else { return }
                self.currentScanResult = result

                let info = DroppedAppInfo(
                    name: name, url: url, icon: icon,
                    appSize: ByteCountFormatter.string(fromByteCount: result.relatedFiles.first?.size ?? 0, countStyle: .file),
                    filesFound: result.fileCount,
                    totalSize: result.formattedTotalSize,
                    scanResult: result
                )
                self.updateDropState(.dropped(info))
            }
        }
    }


    private func performUninstall() {
        guard let scan = currentScanResult else { return }

        let name = scan.appURL.deletingPathExtension().lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: scan.appURL.path)
        let size = scan.formattedTotalSize

        if case .dropped(let info) = dropState {
            updateDropState(.cleaning(info))
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            let result = AppCleaner.clean(scanResult: scan)

            await MainActor.run {
                guard let self else { return }
                self.currentScanResult = nil

                let clean = CleanResult(
                    appName: name, icon: icon,
                    removed: result.removed, failed: result.failed,
                    totalSize: size, failedFiles: result.failedFiles
                )
                self.updateDropState(.cleaned(clean))
                self.autoDismiss(after: 1.5)
            }
        }
    }


    private func cancelDrop() {
        dismissTask?.cancel()
        currentScanResult = nil
        updateDropState(.idle)
        autoDismiss(after: 0.45)
    }

    private func autoDismiss(after delay: TimeInterval) {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.updateDropState(.idle)
                self?.hideWindow()
            }
        }
    }
}


extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        launchAtLoginToggle.state = isLaunchAtLoginEnabled() ? .on : .off
    }
}
