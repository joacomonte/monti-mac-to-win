import Foundation
import Network

/// Servidor HTTP mínimo: sirve la página, la lista en JSON y los archivos.
final class Server: @unchecked Sendable {
    let port: UInt16
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "landrop.server")
    private let lock = NSLock()
    private var items: [SharedItem] = []

    init(port: UInt16) {
        self.port = port
    }

    func start(onError: @escaping @MainActor (String) -> Void) {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        do {
            let listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
            listener.stateUpdateHandler = { state in
                if case .failed(let error) = state {
                    Task { @MainActor in onError("No se pudo abrir el puerto \(self.port): \(error.localizedDescription)") }
                }
            }
            listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            Task { @MainActor in onError(error.localizedDescription) }
        }
    }

    func update(_ items: [SharedItem]) {
        lock.withLock { self.items = items }
    }

    private var snapshot: [SharedItem] {
        lock.withLock { items }
    }

    // MARK: - Conexiones

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveHeader(connection, buffer: Data())
    }

    private func receiveHeader(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16384) { data, _, isComplete, error in
            var buffer = buffer
            if let data { buffer.append(data) }

            if let end = buffer.range(of: Data("\r\n\r\n".utf8)) {
                self.route(String(decoding: buffer[..<end.lowerBound], as: UTF8.self), connection)
            } else if isComplete || error != nil || buffer.count > 65536 {
                connection.cancel()
            } else {
                self.receiveHeader(connection, buffer: buffer)
            }
        }
    }

    private func route(_ head: String, _ connection: NWConnection) {
        let requestLine = head.components(separatedBy: "\r\n").first ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else {
            return send(connection, status: "405 Method Not Allowed", type: "text/plain", body: Data("405".utf8))
        }
        let path = String(parts[1])

        switch path {
        case "/":
            send(connection, type: "text/html; charset=utf-8", body: Data(WebPage.html.utf8))
        case "/api/items":
            send(connection, type: "application/json; charset=utf-8", body: itemsJSON())
        case _ where path.hasPrefix("/file/"):
            let id = String(path.dropFirst("/file/".count))
            guard let item = snapshot.first(where: { $0.id == id }), case .file(let url) = item.kind else {
                return send(connection, status: "404 Not Found", type: "text/plain", body: Data("404".utf8))
            }
            sendFile(url, name: item.name, connection)
        default:
            send(connection, status: "404 Not Found", type: "text/plain", body: Data("404".utf8))
        }
    }

    private func itemsJSON() -> Data {
        struct ItemDTO: Encodable {
            let id: String
            let kind: String
            let name: String
            let size: Int64
            let text: String?
        }
        let dtos = snapshot.map { item -> ItemDTO in
            switch item.kind {
            case .file: ItemDTO(id: item.id, kind: "file", name: item.name, size: item.size, text: nil)
            case .text(let text): ItemDTO(id: item.id, kind: "text", name: item.name, size: item.size, text: text)
            }
        }
        return (try? JSONEncoder().encode(dtos)) ?? Data("[]".utf8)
    }

    // MARK: - Respuestas

    private func send(_ connection: NWConnection, status: String = "200 OK", type: String, body: Data) {
        let header = "HTTP/1.1 \(status)\r\n"
            + "Content-Type: \(type)\r\n"
            + "Content-Length: \(body.count)\r\n"
            + "Cache-Control: no-store\r\n"
            + "Connection: close\r\n\r\n"
        connection.send(content: Data(header.utf8) + body, completion: .contentProcessed { _ in connection.cancel() })
    }

    private func sendFile(_ url: URL, name: String, _ connection: NWConnection) {
        guard let handle = try? FileHandle(forReadingFrom: url),
              let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value
        else {
            return send(connection, status: "404 Not Found", type: "text/plain", body: Data("Archivo no encontrado".utf8))
        }

        let safeChars = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: safeChars) ?? "archivo"
        let header = "HTTP/1.1 200 OK\r\n"
            + "Content-Type: application/octet-stream\r\n"
            + "Content-Length: \(size)\r\n"
            + "Content-Disposition: attachment; filename*=UTF-8''\(encodedName)\r\n"
            + "Connection: close\r\n\r\n"

        connection.send(content: Data(header.utf8), completion: .contentProcessed { error in
            guard error == nil else {
                try? handle.close()
                return connection.cancel()
            }
            self.sendChunks(handle, connection)
        })
    }

    /// Manda el archivo en bloques de 1 MB para no cargarlo entero en memoria.
    private func sendChunks(_ handle: FileHandle, _ connection: NWConnection) {
        guard let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty else {
            try? handle.close()
            return connection.cancel()
        }
        connection.send(content: chunk, completion: .contentProcessed { error in
            guard error == nil else {
                try? handle.close()
                return connection.cancel()
            }
            self.sendChunks(handle, connection)
        })
    }
}
