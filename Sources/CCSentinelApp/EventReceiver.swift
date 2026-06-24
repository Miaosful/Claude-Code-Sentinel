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
        connection.start(queue: DispatchQueue(label: "app.ccsentinel.event-connection"))
        connection.receive(minimumIncompleteLength: 1, maximumLength: maxBodySize + 1) { data, _, _, _ in
            guard let data, !data.isEmpty else {
                send(status: 400, message: "Bad Request", connection: connection)
                return
            }
            guard data.count <= maxBodySize else {
                send(status: 413, message: "Payload Too Large", connection: connection)
                return
            }
            guard let request = HTTPRequest(data: data) else {
                send(status: 400, message: "Bad Request", connection: connection)
                return
            }
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
    }

    private static func send(status: Int, message: String, connection: NWConnection) {
        let response = """
        HTTP/1.1 \(status) \(message)\r
        Content-Length: 0\r
        Connection: close\r
        \r
        """
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
        self.method = String(parts[0])
        self.path = String(parts[1])
        self.body = Data(data[separator.upperBound...])
    }
}
