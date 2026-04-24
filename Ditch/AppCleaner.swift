import Foundation
import AppKit
import os.log

private let log = Logger(subsystem: "com.ditch.app", category: "cleaner")


struct AppScanResult: Sendable {
    let appURL: URL
    let bundleIdentifier: String?
    let relatedFiles: [RelatedFile]
    let totalSize: Int64

    var fileCount: Int { relatedFiles.count }

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

struct RelatedFile: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let size: Int64
    let category: FileCategory

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

enum FileCategory: String, Sendable {
    case app = "Application"
    case appSupport = "App Support"
    case caches = "Caches"
    case preferences = "Preferences"
    case logs = "Logs"
    case savedState = "Saved State"
    case containers = "Containers"
    case cookies = "Cookies"
    case httpStorage = "HTTP Storage"
    case webkit = "WebKit"
    case crashReports = "Crash Reports"
    case launchAgents = "Launch Agents"
    case other = "Other"
}

struct FailedFileEntry: Equatable, Sendable {
    let path: String
    let reason: String
}

struct CleanupResult: Sendable {
    let removed: Int
    let failed: Int
    let failedFiles: [FailedFileEntry]
}

enum AppCleaner {

    // Crawl ~/Library for anything that belongs to this app
    static func scan(appURL: URL) -> AppScanResult {
        let appName = appURL.deletingPathExtension().lastPathComponent
        let bundleID = Bundle(url: appURL)?.bundleIdentifier

        var files: [RelatedFile] = []
        var seen = Set<String>()

        let appSize = directorySize(at: appURL)
        files.append(RelatedFile(url: appURL, size: appSize, category: .app))
        seen.insert(appURL.path)

        let library = NSHomeDirectory() + "/Library"

        var terms: [String] = [appName.lowercased()]
        if let id = bundleID {
            terms.append(id.lowercased())
            if let last = id.split(separator: ".").last, last.lowercased() != appName.lowercased() {
                terms.append(String(last).lowercased())
            }
        }

        let groupIDs = appGroupIdentifiers(for: appURL)
        let teamID = teamIdentifier(for: appURL)

        var groupTerms: [String] = groupIDs.map { $0.lowercased() }
        if let tid = teamID { groupTerms.append(tid.lowercased()) }

        let locations: [(String, FileCategory)] = [
            ("\(library)/Application Support", .appSupport),
            ("\(library)/Caches", .caches),
            ("\(library)/Preferences", .preferences),
            ("\(library)/Logs", .logs),
            ("\(library)/Saved Application State", .savedState),
            ("\(library)/Containers", .containers),
            ("\(library)/Cookies", .cookies),
            ("\(library)/HTTPStorages", .httpStorage),
            ("\(library)/WebKit", .webkit),
            ("\(library)/Application Scripts", .other),
            ("\(library)/LaunchAgents", .launchAgents),
        ]

        let fm = FileManager.default

        for (dir, category) in locations {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents {
                let lower = item.lowercased()
                let matched = terms.contains { term in
                    if let id = bundleID?.lowercased(), lower == id || lower.contains(id) { return true }
                    if lower == term || lower == "\(term).plist" { return true }
                    if category == .savedState && lower.contains(term) { return true }
                    if category == .launchAgents, let id = bundleID?.lowercased(), lower.hasPrefix("\(id).") { return true }
                    return false
                }
                if matched {
                    let url = URL(fileURLWithPath: dir).appendingPathComponent(item)
                    guard seen.insert(url.path).inserted else { continue }
                    files.append(RelatedFile(url: url, size: directorySize(at: url), category: category))
                }
            }
        }

        // Group Containers — matched by bundle ID, app group IDs, and team identifier
        let groupDir = "\(library)/Group Containers"
        if let contents = try? fm.contentsOfDirectory(atPath: groupDir) {
            for item in contents {
                let lower = item.lowercased()
                var matched = false

                if let id = bundleID?.lowercased(), lower.contains(id) {
                    matched = true
                }
                if !matched {
                    matched = groupTerms.contains { lower.hasPrefix($0) || lower.contains($0) }
                }
                if !matched, let tid = teamID?.lowercased(), lower.hasPrefix(tid) {
                    let containerURL = URL(fileURLWithPath: groupDir).appendingPathComponent(item)
                    matched = isGroupContainerRelated(containerURL: containerURL, bundleID: bundleID, appName: appName)
                }
                if matched {
                    let url = URL(fileURLWithPath: groupDir).appendingPathComponent(item)
                    guard seen.insert(url.path).inserted else { continue }
                    files.append(RelatedFile(url: url, size: directorySize(at: url), category: .containers))
                }
            }
        }

        // Crash reports
        let crashDirs = [
            NSHomeDirectory() + "/Library/Logs/DiagnosticReports",
            "/Library/Logs/DiagnosticReports"
        ]
        for dir in crashDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where terms.contains(where: { item.lowercased().contains($0) }) {
                let url = URL(fileURLWithPath: dir).appendingPathComponent(item)
                guard seen.insert(url.path).inserted else { continue }
                files.append(RelatedFile(url: url, size: fileSize(at: url), category: .crashReports))
            }
        }

        let total = files.reduce(into: Int64(0)) { $0 += $1.size }
        return AppScanResult(appURL: appURL, bundleIdentifier: bundleID, relatedFiles: files, totalSize: total)
    }

    // Trash everything from the scan. Asks for admin password if needed.
    static func clean(scanResult: AppScanResult) -> CleanupResult {
        let fm = FileManager.default
        var removed = 0
        var failed = 0
        var failedFiles: [FailedFileEntry] = []

        for file in scanResult.relatedFiles {
            do {
                try fm.trashItem(at: file.url, resultingItemURL: nil)
                removed += 1
            } catch {
                if trashWithPrivileges(url: file.url) {
                    removed += 1
                } else {
                    log.error("Failed to trash \(file.url.lastPathComponent): \(error.localizedDescription)")
                    failed += 1
                    failedFiles.append(FailedFileEntry(path: file.url.lastPathComponent, reason: error.localizedDescription))
                }
            }
        }

        removeFromDock(bundleIdentifier: scanResult.bundleIdentifier, appURL: scanResult.appURL)
        return CleanupResult(removed: removed, failed: failed, failedFiles: failedFiles)
    }

    // Last resort: use AppleScript to get admin rights and force-trash
    private static func trashWithPrivileges(url: URL) -> Bool {
        let escaped = url.path.replacingOccurrences(of: "'", with: "'\\''")
        let source = "do shell script \"mv '\(escaped)' ~/.Trash/\" with administrator privileges"
        guard let script = NSAppleScript(source: source) else { return false }

        var error: NSDictionary?
        script.executeAndReturnError(&error)
        return error == nil
    }

    // Yank the app from the Dock if it was pinned there
    private static func removeFromDock(bundleIdentifier: String?, appURL: URL) {
        let plistPath = NSHomeDirectory() + "/Library/Preferences/com.apple.dock.plist"
        guard let plist = NSMutableDictionary(contentsOfFile: plistPath),
              let apps = plist["persistent-apps"] as? [[String: Any]] else { return }

        let appPath = appURL.path
        let bundleID = bundleIdentifier?.lowercased()

        let filtered = apps.filter { entry in
            guard let tile = entry["tile-data"] as? [String: Any] else { return true }
            if let bundleID, let id = tile["bundle-identifier"] as? String, id.lowercased() == bundleID { return false }
            if let data = tile["file-data"] as? [String: Any],
               let path = data["_CFURLString"] as? String,
               path.contains(appPath) { return false }
            return true
        }

        guard filtered.count < apps.count else { return }

        plist["persistent-apps"] = filtered
        plist.write(toFile: plistPath, atomically: true)

        let task = Process()
        task.launchPath = "/usr/bin/killall"
        task.arguments = ["Dock"]
        try? task.run()
    }


    private static func appGroupIdentifiers(for appURL: URL) -> [String] {
        guard let data = codesignOutput(args: ["-d", "--entitlements", "-", "--xml", appURL.path], stderr: false),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return []
        }

        var ids: [String] = []
        if let groups = plist["com.apple.security.application-groups"] as? [String] { ids.append(contentsOf: groups) }
        if let team = plist["com.apple.developer.team-identifier"] as? String { ids.append(team) }
        return ids
    }

    private static func teamIdentifier(for appURL: URL) -> String? {
        guard let data = codesignOutput(args: ["-dvv", appURL.path], stderr: true),
              let output = String(data: data, encoding: .utf8) else { return nil }

        for line in output.components(separatedBy: "\n") where line.hasPrefix("TeamIdentifier=") {
            let id = line.replacingOccurrences(of: "TeamIdentifier=", with: "").trimmingCharacters(in: .whitespaces)
            if id != "not set" && !id.isEmpty { return id }
        }
        return nil
    }

    private static func codesignOutput(args: [String], stderr: Bool) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = args

        let pipe = Pipe()
        if stderr {
            process.standardOutput = Pipe()
            process.standardError = pipe
        } else {
            process.standardOutput = pipe
            process.standardError = Pipe()
        }

        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return data.isEmpty ? nil : data
    }


    private static func isGroupContainerRelated(containerURL: URL, bundleID: String?, appName: String) -> Bool {
        let fm = FileManager.default
        let nameLower = appName.lowercased()
        let idLower = bundleID?.lowercased()

        let metaPlist = containerURL.appendingPathComponent("Library/Preferences/.com.apple.group.container.plist")
        if fm.fileExists(atPath: metaPlist.path),
           let dict = NSDictionary(contentsOf: metaPlist) {
            let desc = dict.description.lowercased()
            if let id = idLower, desc.contains(id) { return true }
            if desc.contains(nameLower) { return true }
        }

        for dir in [containerURL.path, containerURL.appendingPathComponent("Library").path] {
            guard let items = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in items {
                let lower = item.lowercased()
                if lower.contains(nameLower) { return true }
                if let id = idLower, lower.contains(id) { return true }
            }
        }

        return false
    }


    private static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &isDir) else { return 0 }
        guard isDir.boolValue else { return fileSize(at: url) }

        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: Array(keys), options: [.skipsHiddenFiles]) else { return 0 }

        var total: Int64 = 0
        var count = 0

        for case let fileURL as URL in enumerator {
            count += 1
            if count > 50_000 { break }
            if let values = try? fileURL.resourceValues(forKeys: keys) {
                total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
            }
        }
        return total
    }

    private static func fileSize(at url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]) else { return 0 }
        return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
    }
}
