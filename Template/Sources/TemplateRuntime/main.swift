import AppKit
import WebKit

struct AppConfig: Decodable {
    let url: String
    let title: String
}

func loadConfig() -> AppConfig {
    if let url = Bundle.main.url(forResource: "config", withExtension: "json"),
       let data = try? Data(contentsOf: url),
       let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
        return config
    }
    return AppConfig(url: "https://example.com", title: "WebApp")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    let config = loadConfig()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 840)
        let width: CGFloat = min(1280, screenFrame.width - 80)
        let height: CGFloat = min(840, screenFrame.height - 80)
        let rect = NSRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.midY - height / 2,
            width: width,
            height: height
        )

        window = NSWindow(
            contentRect: rect,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = config.title
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false

        let webConfig = WKWebViewConfiguration()
        webConfig.websiteDataStore = .default()
        webView = WKWebView(frame: .zero, configuration: webConfig)
        webView.autoresizingMask = [.width, .height]
        window.contentView = webView

        if let url = URL(string: config.url) {
            webView.load(URLRequest(url: url))
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
