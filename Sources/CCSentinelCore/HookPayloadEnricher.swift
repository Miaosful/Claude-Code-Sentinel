import Foundation

public enum HookPayloadEnricher {
    public enum EnrichmentError: Error, Equatable {
        case malformed
    }

    public static func addClaudePID(_ pid: Int32, to data: Data) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw EnrichmentError.malformed
        }

        object["claude_pid"] = Int(pid)
        return try JSONSerialization.data(withJSONObject: object)
    }
}
