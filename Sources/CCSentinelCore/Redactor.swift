import Foundation

public enum Redactor {
    public static func safeSummary(_ value: String, maxLength: Int = 120) -> String {
        var output = value
        output = output.replacingOccurrences(
            of: #"(?i)(bearer\s+)[A-Za-z0-9._\-]+"#,
            with: "$1[redacted]",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: #"(?i)(api[_-]?key=)[^&\s]+"#,
            with: "$1[redacted]",
            options: .regularExpression
        )
        output = output.replacingOccurrences(
            of: #"sk-[A-Za-z0-9._\-]+"#,
            with: "[redacted]",
            options: .regularExpression
        )

        if output.count > maxLength {
            return String(output.prefix(maxLength)) + "..."
        }
        return output
    }
}
