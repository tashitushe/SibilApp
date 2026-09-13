import AppKit
import Foundation
import UniformTypeIdentifiers

enum GenState: Equatable {
    case idle
    case working(String)
    case done(path: String)
    case failed(String)
}

enum IconMode: String {
    case auto
    case custom
}

@MainActor
final class GeneratorEngine: ObservableObject {
    @Published var urlText: String = ""
    @Published var nameText: String = ""
    @Published var iconMode: IconMode = .auto
    @Published var customIconURL: URL?
    @Published var state: GenState = .idle

    var canGenerate: Bool {
        if case .working = state { return false }
        return !normalizedURLString.isEmpty
    }

    private var normalizedURLString: String {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.contains("://") { return trimmed }
        return "https://\(trimmed)"
    }

    func pickCustomIcon() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff, .bmp, .icns]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "Choose a logo image"
        if panel.runModal() == .OK {
            customIconURL = panel.url
        }
    }

    func generate() {
        let rawURL = normalizedURLString
        guard let url = URL(string: rawURL), let host = url.host else {
            state = .failed("Enter a valid link.")
            return
        }
        let appName = resolvedAppName(host: host)
        let iconMode = self.iconMode
        let customIconPath = self.customIconURL?.path

        if iconMode == .custom && customIconPath == nil {
            state = .failed("Choose a logo image first, or switch to Auto.")
            return
        }

        Task {
            do {
                state = .working("Preparing app bundle…")
                let destination = try await Task.detached(priority: .userInitiated) { [weak self] in
                    try self?.buildApp(
                        url: rawURL,
                        appName: appName,
                        host: host,
                        iconMode: iconMode,
                        customIconPath: customIconPath
                    ) ?? ""
                }.value

                state = .done(path: destination)
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: destination)])
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func reset() {
        state = .idle
        urlText = ""
        nameText = ""
        iconMode = .auto
        customIconURL = nil
    }

    private func resolvedAppName(host: String) -> String {
        let trimmedName = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty { return trimmedName }
        var base = host.replacingOccurrences(of: "www.", with: "")
        if let dot = base.firstIndex(of: ".") {
            base = String(base[base.startIndex..<dot])
        }
        return base.prefix(1).uppercased() + base.dropFirst()
    }

    private nonisolated func buildApp(
        url: String,
        appName: String,
        host: String,
        iconMode: IconMode,
        customIconPath: String?
    ) throws -> String {
        guard let templateURL = Bundle.main.url(forResource: "Template", withExtension: "app") else {
            throw ForgeError.message("Template bundle missing from app resources.")
        }

        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
        var destination = desktop.appendingPathComponent("\(appName).app")
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = desktop.appendingPathComponent("\(appName) \(suffix).app")
            suffix += 1
        }

        try FileManager.default.copyItem(at: templateURL, to: destination)

        // Write runtime config (url + window title) read by the wrapped app at launch.
        let resourcesDir = destination.appendingPathComponent("Contents/Resources")
        let config: [String: String] = ["url": url, "title": appName]
        let configData = try JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted])
        try configData.write(to: resourcesDir.appendingPathComponent("config.json"))

        // Patch Info.plist so Finder/Launchpad show the right name and a unique bundle id.
        let plistURL = destination.appendingPathComponent("Contents/Info.plist")
        if var plist = NSDictionary(contentsOf: plistURL) as? [String: Any] {
            plist["CFBundleName"] = appName
            plist["CFBundleDisplayName"] = appName
            let slug = appName.lowercased().replacingOccurrences(of: " ", with: "-")
            plist["CFBundleIdentifier"] = "com.sibilapp.generated.\(slug)"
            let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try plistData.write(to: plistURL)
        }

        // Resolve the icon: either the user's chosen logo, or a best-effort favicon fetch.
        // Either way, falls back to the bundled generic icon on failure.
        let sourceImagePath: String?
        switch iconMode {
        case .custom:
            sourceImagePath = customIconPath
        case .auto:
            sourceImagePath = fetchFavicon(host: host)
        }

        if let sourceImagePath, let icnsPath = try? makeIcns(fromImageAt: sourceImagePath) {
            let iconDestination = resourcesDir.appendingPathComponent("AppIcon.icns")
            try? FileManager.default.removeItem(at: iconDestination)
            try? FileManager.default.copyItem(at: URL(fileURLWithPath: icnsPath), to: iconDestination)
        }

        codesignAdHoc(at: destination)
        return destination.path
    }

    /// Downloads a favicon and returns the path to a temp file holding it, or nil on failure.
    private nonisolated func fetchFavicon(host: String) -> String? {
        guard let serviceURL = URL(string: "https://www.google.com/s2/favicons?domain=\(host)&sz=256") else {
            return nil
        }
        let semaphore = DispatchSemaphore(value: 0)
        var result: Data?
        let task = URLSession.shared.dataTask(with: serviceURL) { data, response, _ in
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                result = data
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 8)

        guard let data = result else { return nil }
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        do {
            try data.write(to: tmp)
            return tmp.path
        } catch {
            return nil
        }
    }

    private nonisolated func makeIcns(fromImageAt sourcePath: String) throws -> String {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

        // Normalize any input format (jpg/heic/tiff/icns/...) to a flat PNG first.
        let normalizedPNG = tmp.appendingPathComponent("source.png")
        try runSipsConvert(sourcePath, out: normalizedPNG.path)

        let iconset = tmp.appendingPathComponent("icon.iconset")
        try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

        for size in [16, 32, 64, 128, 256, 512] {
            try runSipsResize(normalizedPNG.path, size: size, out: iconset.appendingPathComponent("icon_\(size)x\(size).png").path)
            try runSipsResize(normalizedPNG.path, size: size * 2, out: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png").path)
        }

        let icnsOut = tmp.appendingPathComponent("AppIcon.icns")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
        process.arguments = ["-c", "icns", iconset.path, "-o", icnsOut.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ForgeError.message("iconutil failed")
        }
        return icnsOut.path
    }

    private nonisolated func runSipsConvert(_ source: String, out: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = ["-s", "format", "png", source, "--out", out]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw ForgeError.message("Could not read that image.")
        }
    }

    private nonisolated func runSipsResize(_ source: String, size: Int, out: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        process.arguments = ["-z", "\(size)", "\(size)", source, "--out", out]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }

    private nonisolated func codesignAdHoc(at path: URL) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--deep", "--sign", "-", path.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}

enum ForgeError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}
