import Foundation

struct SharedItem: Identifiable {
    enum Kind {
        case file(URL)
        case text(String)
    }

    let id = String(UUID().uuidString.prefix(8)).lowercased()
    let kind: Kind
    let name: String
    let size: Int64
}

@MainActor
final class Store: ObservableObject {
    @Published private(set) var items: [SharedItem] = [] {
        didSet { server.update(items) }
    }
    @Published private(set) var serverError: String?

    let server = Server(port: 8000)

    // Las carpetas se comprimen acá; se borra al abrir y al cerrar la app.
    private nonisolated static let zipDir = FileManager.default.temporaryDirectory.appendingPathComponent("LanDrop")

    var url: String { "http://\(localIPAddress() ?? "localhost"):\(server.port)" }

    init() {
        cleanup()
        server.start { [weak self] message in
            self?.serverError = message
        }
    }

    func addFiles(_ urls: [URL]) {
        for url in urls {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
            if isDir.boolValue {
                Task {
                    if let zip = await Self.zip(url) { append(file: zip) }
                }
            } else {
                append(file: url)
            }
        }
    }

    func addText(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let firstLine = trimmed.components(separatedBy: .newlines).first ?? trimmed
        items.insert(SharedItem(kind: .text(trimmed), name: firstLine, size: Int64(trimmed.utf8.count)), at: 0)
    }

    func remove(_ item: SharedItem) {
        items.removeAll { $0.id == item.id }
    }

    func clear() {
        items.removeAll()
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: Self.zipDir)
    }

    private func append(file url: URL) {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value ?? 0
        items.insert(SharedItem(kind: .file(url), name: url.lastPathComponent, size: size), at: 0)
    }

    private nonisolated static func zip(_ folder: URL) async -> URL? {
        let dest = zipDir
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent(folder.lastPathComponent + ".zip")
        try? FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", folder.path, dest.path]
        return await withCheckedContinuation { continuation in
            process.terminationHandler = { p in
                continuation.resume(returning: p.terminationStatus == 0 ? dest : nil)
            }
            do { try process.run() } catch { continuation.resume(returning: nil) }
        }
    }
}

/// IPv4 de la red local (Wi-Fi / Ethernet).
func localIPAddress() -> String? {
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
    defer { freeifaddrs(ifaddr) }

    var addresses: [String: String] = [:]
    for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
        guard let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST)
        addresses[String(cString: ptr.pointee.ifa_name)] = String(cString: host)
    }
    return addresses["en0"] ?? addresses["en1"] ?? addresses.first { !$0.key.hasPrefix("lo") }?.value
}
