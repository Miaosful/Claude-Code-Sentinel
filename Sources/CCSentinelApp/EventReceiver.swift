import Foundation
import Network
import CCSentinelCore

final class EventReceiver {
    typealias EventHandler = @Sendable (NormalizedEvent) -> Void

    private let listener: NWListener
    private let handler: EventHandler
    private let maxBodySize = 512 * 1024

    init(port: UInt16 = 47281, handler: @escaping EventHandler) throws {
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw ReceiverError.invalidPort
        }
        self.listener = try NWListener(using: .tcp, on: endpointPort)
        self.handler = handler
    }

    func start(queue: DispatchQueue = DispatchQueue(label: "app.ccsentinel.event-receiver")) {
        listener.newConnectionHandler = { [handler, maxBodySize] connection in
            Self.handle(connection: connection, maxBodySize: maxBodySize, handler: handler)
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener.cancel()
    }

    private static func handle(connection: NWConnection, maxBodySize: Int, handler: @escaping EventHandler) {
        let queue = DispatchQueue(label: "app.ccsentinel.event-connection")
        connection.start(queue: queue)
        receiveRequest(connection: connection, buffer: Data(), maxBodySize: maxBodySize, handler: handler)
    }

    private static func receiveRequest(
        connection: NWConnection,
        buffer: Data,
        maxBodySize: Int,
        handler: @escaping EventHandler
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: maxBodySize + 4096) { data, _, isComplete, _ in
            var nextBuffer = buffer
            if let data {
                nextBuffer.append(data)
            }

            if nextBuffer.count > maxBodySize + 4096 {
                send(status: 413, message: "Payload Too Large", connection: connection)
                return
            }

            if let request = HTTPRequest(data: nextBuffer) {
                handle(request: request, connection: connection, handler: handler)
                return
            }

            if isComplete {
                send(status: 400, message: "Bad Request", connection: connection)
                return
            }

            receiveRequest(connection: connection, buffer: nextBuffer, maxBodySize: maxBodySize, handler: handler)
        }
    }

    private static func handle(request: HTTPRequest, connection: NWConnection, handler: @escaping EventHandler) {
        guard request.method == "POST", request.path == "/events" else {
            send(status: 404, message: "Not Found", connection: connection)
            return
        }

        do {
            let event = try EventNormalizer.normalize(request.body)
            handler(event)
            send(status: 202, message: "Accepted", connection: connection)
        } catch {
            send(status: 400, message: "Bad Request", connection: connection)
        }
    }

    private static func send(status: Int, message: String, connection: NWConnection) {
        let response = "HTTP/1.1 \(status) \(message)\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    enum ReceiverError: Error {
        case invalidPort
    }
}

private struct HTTPRequest {
    var method: String
    var path: String
    var body: Data

    init?(data: Data) {
        guard let separator = data.firstRange(of: Data("\r\n\r\n".utf8)) else {
            return nil
        }
        let headerData = data[..<separator.lowerBound]
        guard let header = String(data: headerData, encoding: .utf8) else {
            return nil
        }
        let requestLine = header.split(separator: "\r\n", maxSplits: 1).first ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            return nil
        }
        let contentLength = HTTPRequest.contentLength(from: header)
        let body = Data(data[separator.upperBound...])
        guard body.count >= contentLength else {
            return nil
        }
        self.method = String(parts[0])
        self.path = String(parts[1])
        self.body = Data(body.prefix(contentLength))
    }

    private static func contentLength(from header: String) -> Int {
        for line in header.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            if parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "content-length" {
                return Int(parts[1].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
            }
        }
        return 0
    }
}
