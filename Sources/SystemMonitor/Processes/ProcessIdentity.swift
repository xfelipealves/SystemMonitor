import Darwin
import Foundation

/// What a process is grouped under in the menu: an app, or a named command-line or system process.
struct ProcessIdentity: Equatable {
    enum Kind: Equatable {
        case app(bundlePath: String)
        case commandLine
        case system
    }

    /// Outermost `.app` bundle path, or `proc:<binary name>` for processes outside an app.
    let key: String
    let name: String
    let kind: Kind

    static func of(pid: pid_t) -> ProcessIdentity {
        let path = LibProc.executablePath(of: pid)
        // XPC services (Safari's web pages, for example) belong to the app that launched them.
        let responsiblePath = path.contains(".xpc/")
            ? LibProc.responsiblePID(for: pid).map(LibProc.executablePath(of:))
            : nil
        return classify(path: path, processName: LibProc.name(of: pid), responsiblePath: responsiblePath)
    }

    /// The grouping rule, free of system calls so it can be unit tested.
    static func classify(path: String, processName: String, responsiblePath: String?) -> ProcessIdentity {
        if let bundlePath = appBundlePath(in: path) ?? responsiblePath.flatMap(appBundlePath(in:)) {
            return ProcessIdentity(key: bundlePath, name: appName(bundlePath), kind: .app(bundlePath: bundlePath))
        }

        let binaryName = path.isEmpty ? processName : (path as NSString).lastPathComponent
        let name = binaryName == "com.apple.WebKit.WebContent" ? L10n.webPages : binaryName
        let isSystem = path.isEmpty || systemPrefixes.contains { path.hasPrefix($0) }
        return ProcessIdentity(key: "proc:" + binaryName, name: name, kind: isSystem ? .system : .commandLine)
    }

    /// "/Applications/Foo.app/Contents/MacOS/Foo" → "/Applications/Foo.app" (outermost bundle).
    static func appBundlePath(in path: String) -> String? {
        guard let range = path.range(of: ".app/") else { return nil }
        return String(path[..<range.lowerBound]) + ".app"
    }

    private static let systemPrefixes = ["/System/", "/usr/", "/sbin/", "/bin/", "/Library/Apple/"]

    private static func appName(_ bundlePath: String) -> String {
        let name = FileManager.default.displayName(atPath: bundlePath)
        return name.hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}
