// WXGUARD PRO for macOS: a self-contained .app around the static web client.
//
// The client is just files (web/tools/package.mjs assembles them into Contents/Resources/web).
// Web Bluetooth and Web Serial exist only in Chromium browsers, and only for a page from a secure
// context, so this app:
//
//   1. serves Contents/Resources/web on http://127.0.0.1:<port>/ (localhost is a secure context),
//   2. opens it with an installed Chrome, Edge, Brave or Chromium in app mode (`--app=`): its own
//      window with no tabs or address bar, under a profile that belongs to WXGUARD PRO only,
//   3. stops the server and quits when that browser process quits.
//
// No Node.js, Python or other runtime is needed. The port stays the same between launches
// (default 8137, or WXGUARD_PORT) because the browser keeps settings and radio permissions per
// origin, and a new port would be a new origin.
//
// `--serve-only [--port N]` runs just the file server in the foreground, for CI and diagnostics.

import AppKit
import Darwin
import Foundation

let appName = "WXGUARD PRO"
let defaultPort: UInt16 = 8137
/// Answered by this server only, so a second launch can tell its own server from a stranger's.
let markerPath = "/__wxguard-app"

// MARK: - Logging

let logURL: URL = {
    let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("\(appName).log")
}()

func log(_ message: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
    FileHandle.standardError.write(line.data(using: .utf8)!)
    if let handle = try? FileHandle(forWritingTo: logURL) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        try? handle.close()
    } else {
        try? line.data(using: .utf8)!.write(to: logURL)
    }
}

// MARK: - Static file server

let contentTypes: [String: String] = [
    "html": "text/html; charset=utf-8", "js": "text/javascript; charset=utf-8",
    "mjs": "text/javascript; charset=utf-8", "css": "text/css; charset=utf-8",
    "json": "application/json; charset=utf-8", "geojson": "application/geo+json",
    "webmanifest": "application/manifest+json", "svg": "image/svg+xml", "png": "image/png",
    "ico": "image/x-icon", "woff2": "font/woff2", "md": "text/markdown; charset=utf-8",
]

enum ServerError: Error {
    case addressInUse
    case socket(String)
}

final class StaticServer {
    let root: String
    let port: UInt16
    private var listenFD: Int32 = -1

    init(root: URL, port: UInt16) {
        self.root = root.standardizedFileURL.resolvingSymlinksInPath().path
        self.port = port
    }

    func start() throws {
        signal(SIGPIPE, SIG_IGN)
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw ServerError.socket("socket: \(String(cString: strerror(errno)))") }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        if bound != 0 {
            let code = errno
            close(fd)
            if code == EADDRINUSE { throw ServerError.addressInUse }
            throw ServerError.socket("bind: \(String(cString: strerror(code)))")
        }
        guard listen(fd, 64) == 0 else {
            close(fd)
            throw ServerError.socket("listen: \(String(cString: strerror(errno)))")
        }
        listenFD = fd
        Thread.detachNewThread { [self] in acceptLoop(fd) }
    }

    func stop() {
        if listenFD >= 0 { close(listenFD); listenFD = -1 }
    }

    private func acceptLoop(_ fd: Int32) {
        while true {
            let client = accept(fd, nil, nil)
            if client < 0 {
                if errno == EINTR { continue }
                return  // closed by stop()
            }
            var yes: Int32 = 1
            setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout<Int32>.size))
            var timeout = timeval(tv_sec: 10, tv_usec: 0)
            setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                handle(client)
                close(client)
            }
        }
    }

    private func handle(_ fd: Int32) {
        guard let head = readHead(fd) else { return }
        let parts = head.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else { return reply(fd, 400, "bad request") }
        let method = parts[0]
        guard method == "GET" || method == "HEAD" else { return reply(fd, 405, "only GET") }
        let target = parts[1].split(separator: "?", maxSplits: 1).first.map(String.init) ?? "/"

        if target == markerPath {
            let body = Data("{\"app\":\"wxguard-pro\"}".utf8)
            return send(fd, 200, "application/json", body: body, head: method == "HEAD")
        }
        guard let path = resolve(target) else { return reply(fd, 404, "not found") }
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe) else {
            return reply(fd, 404, "not found")
        }
        let ext = (path as NSString).pathExtension.lowercased()
        send(fd, 200, contentTypes[ext] ?? "application/octet-stream", body: data, head: method == "HEAD")
    }

    /// The request line, once the whole header block has arrived. Headers are not needed.
    private func readHead(_ fd: Int32) -> String? {
        var buffer = [UInt8]()
        var chunk = [UInt8](repeating: 0, count: 4096)
        let end: [UInt8] = [13, 10, 13, 10]
        while buffer.count < 16_384 {
            let n = recv(fd, &chunk, chunk.count, 0)
            if n <= 0 { return nil }
            buffer.append(contentsOf: chunk[0..<n])
            if buffer.count >= 4, (0...(buffer.count - 4)).contains(where: { Array(buffer[$0..<$0 + 4]) == end }) {
                break
            }
        }
        guard let text = String(bytes: buffer, encoding: .utf8) else { return nil }
        return text.components(separatedBy: "\r\n").first
    }

    /// A URL path to a file inside `root`, or nil. A URL can say `..` (also percent-encoded),
    /// so resolve first and then check the result is still inside.
    func resolve(_ urlPath: String) -> String? {
        guard let decoded = urlPath.removingPercentEncoding, !decoded.contains("\0") else { return nil }
        var path = URL(fileURLWithPath: root + "/" + decoded).standardizedFileURL.resolvingSymlinksInPath().path
        guard path == root || path.hasPrefix(root + "/") else { return nil }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return nil }
        if isDir.boolValue {
            path += "/index.html"
            guard FileManager.default.fileExists(atPath: path) else { return nil }
        }
        return path
    }

    private func reply(_ fd: Int32, _ status: Int, _ text: String) {
        send(fd, status, "text/plain; charset=utf-8", body: Data(text.utf8), head: false)
    }

    private func send(_ fd: Int32, _ status: Int, _ type: String, body: Data, head: Bool) {
        let reason = [200: "OK", 400: "Bad Request", 404: "Not Found", 405: "Method Not Allowed"][status] ?? "Error"
        let header = "HTTP/1.1 \(status) \(reason)\r\nContent-Type: \(type)\r\nContent-Length: \(body.count)\r\n"
            + "Cache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nConnection: close\r\n\r\n"
        guard writeAll(fd, Data(header.utf8)), !head else { return }
        _ = writeAll(fd, body)
    }

    private func writeAll(_ fd: Int32, _ data: Data) -> Bool {
        data.withUnsafeBytes { raw -> Bool in
            guard var p = raw.baseAddress else { return true }
            var left = raw.count
            while left > 0 {
                let n = Darwin.send(fd, p, left, 0)
                if n < 0 { if errno == EINTR { continue }; return false }
                p += n
                left -= n
            }
            return true
        }
    }
}

/// Whether the server already on `port` is another WXGUARD PRO, rather than some other program.
func portBelongsToWXGUARD(_ port: UInt16) -> Bool {
    guard let url = URL(string: "http://127.0.0.1:\(port)\(markerPath)") else { return false }
    var request = URLRequest(url: url)
    request.timeoutInterval = 2
    let done = DispatchSemaphore(value: 0)
    var ours = false
    URLSession.shared.dataTask(with: request) { data, _, _ in
        if let data, String(data: data, encoding: .utf8)?.contains("wxguard-pro") == true { ours = true }
        done.signal()
    }.resume()
    _ = done.wait(timeout: .now() + 3)
    return ours
}

// MARK: - Browser

struct Browser {
    let name: String
    let appURL: URL
}

/// Chromium browsers only: Safari and Firefox have neither Web Bluetooth nor Web Serial.
func findBrowser() -> Browser? {
    let candidates = [
        ("com.google.Chrome", "Google Chrome"),
        ("com.microsoft.edgemac", "Microsoft Edge"),
        ("com.brave.Browser", "Brave Browser"),
        ("org.chromium.Chromium", "Chromium"),
    ]
    for (id, name) in candidates {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id),
              let exe = Bundle(url: url)?.executableURL,
              FileManager.default.isExecutableFile(atPath: exe.path) else { continue }
        return Browser(name: name, appURL: url)
    }
    return nil
}

// MARK: - App

func configuredPort() -> UInt16 {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--port"), i + 1 < args.count, let p = UInt16(args[i + 1]), p > 0 { return p }
    if let env = ProcessInfo.processInfo.environment["WXGUARD_PORT"], let p = UInt16(env), p > 0 { return p }
    return defaultPort
}

func webRoot() -> URL? {
    let args = CommandLine.arguments
    if let i = args.firstIndex(of: "--root"), i + 1 < args.count {
        return URL(fileURLWithPath: args[i + 1])
    }
    return Bundle.main.resourceURL?.appendingPathComponent("web")
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var server: StaticServer?
    var browser: Browser?
    var browserApp: NSRunningApplication?
    var port: UInt16 = defaultPort

    var pageURL: String { "http://127.0.0.1:\(port)/" }

    var profileDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/\(appName)/Browser Profile")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        port = configuredPort()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(appTerminated(_:)),
            name: NSWorkspace.didTerminateApplicationNotification, object: nil)
        guard let root = webRoot(), FileManager.default.fileExists(atPath: root.appendingPathComponent("index.html").path) else {
            return fail("The app is incomplete: its web client is missing. Download WXGUARD PRO again.")
        }
        guard let found = findBrowser() else {
            let alert = NSAlert()
            alert.messageText = "\(appName) needs Google Chrome, Microsoft Edge, Brave or Chromium"
            alert.informativeText = "Radio connections use Web Bluetooth and Web Serial, which only Chromium-based browsers provide. Install one, then open \(appName) again."
            alert.addButton(withTitle: "Get Google Chrome")
            alert.addButton(withTitle: "Quit")
            NSApp.activate(ignoringOtherApps: true)
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "https://www.google.com/chrome/")!)
            }
            return NSApp.terminate(nil)
        }
        browser = found

        let server = StaticServer(root: root, port: port)
        do {
            try server.start()
            self.server = server
            log("serving \(root.path) at \(pageURL)")
        } catch ServerError.addressInUse {
            if portBelongsToWXGUARD(port) {
                // Another copy is already serving (for example one still quitting). Use it.
                log("port \(port) already served by \(appName); reusing it")
            } else {
                return fail("Port \(port) is already in use by another program.\n\nQuit that program and open \(appName) again. Advanced: launch with a different port, e.g. in Terminal: WXGUARD_PORT=8138 open -a \"\(appName)\". Settings and radio permissions are saved per port.")
            }
        } catch {
            return fail("Could not start the local server: \(error)")
        }
        launchBrowser(primary: true)
    }

    /// The browser is started through LaunchServices as a new instance, not as a child process.
    /// A child process would make this app macOS's "responsible process" for the browser, so the
    /// browser's own self-update (which rewrites its .app) would be blocked by App Management and
    /// reported as "WXGUARD PRO was prevented from modifying apps on your Mac".
    ///
    /// The first instance owns this profile; its exit is how the app knows the window is gone for
    /// good. A later launch with the same profile hands its URL to that instance and exits, so it
    /// is not tracked.
    func launchBrowser(primary: Bool) {
        guard let browser else { return }
        try? FileManager.default.createDirectory(at: profileDir, withIntermediateDirectories: true)
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.activates = true
        config.addsToRecentItems = false
        config.arguments = [
            "--app=\(pageURL)",
            "--user-data-dir=\(profileDir.path)",
            "--no-first-run",
            "--no-default-browser-check",
            "--window-size=1360,880",
        ]
        NSWorkspace.shared.openApplication(at: browser.appURL, configuration: config) { running, error in
            DispatchQueue.main.async { [self] in
                guard let running, error == nil else {
                    return fail("Could not open \(browser.name): \(error?.localizedDescription ?? "unknown error")")
                }
                log("opened \(pageURL) in \(browser.name) app window (pid \(running.processIdentifier))")
                guard primary else { return }
                browserApp = running
                sawWindow = false
                emptyPolls = 0
                watchWindows()
            }
        }
    }

    @objc func appTerminated(_ note: Notification) {
        guard let gone = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let ours = browserApp, gone.processIdentifier == ours.processIdentifier else { return }
        log("\(browser?.name ?? "browser") window closed; stopping")
        browserApp = nil
        NSApp.terminate(nil)
    }

    /// Opening the app again (Finder, Dock, Spotlight) brings the existing window forward.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let app = browserApp, !app.isTerminated {
            if windowCount(pid: app.processIdentifier) > 0 {
                app.activate()
            } else {
                launchBrowser(primary: false)
            }
        } else {
            launchBrowser(primary: true)
        }
        return false
    }

    /// Normal (layer 0) windows the browser process has, minimized or hidden ones included.
    /// Counting needs no Screen Recording permission; only window titles would.
    func windowCount(pid: Int32) -> Int {
        guard let list = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return 0 }
        return list.filter { w in
            guard (w[kCGWindowOwnerPID as String] as? Int32) == pid,
                  (w[kCGWindowLayer as String] as? Int) == 0,
                  let b = w[kCGWindowBounds as String] as? [String: CGFloat] else { return false }
            return (b["Width"] ?? 0) > 120 && (b["Height"] ?? 0) > 120
        }.count
    }

    /// On macOS a browser keeps running after its last window closes. For an app window that would
    /// leave a windowless browser in the Dock and this app's server running, so once the window has
    /// appeared and then been gone for a few seconds, quit the browser (which quits this app).
    var sawWindow = false
    var emptyPolls = 0
    func watchWindows() {
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self, let app = self.browserApp, !app.isTerminated else { timer.invalidate(); return }
            if self.windowCount(pid: app.processIdentifier) > 0 {
                self.sawWindow = true
                self.emptyPolls = 0
            } else if self.sawWindow {
                self.emptyPolls += 1
                if self.emptyPolls >= 3 {
                    timer.invalidate()
                    log("app window closed; quitting browser")
                    app.terminate()
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        server?.stop()
        if let app = browserApp, !app.isTerminated { app.terminate() }
    }

    func fail(_ message: String) {
        log("error: \(message)")
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "\(appName) could not start"
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.terminate(nil)
    }
}

// MARK: - Entry point

if CommandLine.arguments.contains("--serve-only") {
    guard let root = webRoot() else { log("no web root"); exit(1) }
    let server = StaticServer(root: root, port: configuredPort())
    do { try server.start() } catch {
        log("could not serve on port \(configuredPort()): \(error)")
        exit(1)
    }
    print("WXGUARD PRO serving \(server.root) at http://127.0.0.1:\(server.port)/")
    fflush(stdout)
    dispatchMain()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
