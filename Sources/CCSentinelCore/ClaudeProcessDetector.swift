import Foundation
#if canImport(Darwin)
import Darwin
#endif

public struct ProcessListEntry: Equatable, Sendable {
    public var pid: Int32
    public var parentPID: Int32
    public var command: String

    public init(pid: Int32, parentPID: Int32, command: String) {
        self.pid = pid
        self.parentPID = parentPID
        self.command = command
    }
}

public struct ProcessIdentity: Equatable, Sendable {
    public var pid: Int32
    public var parentPID: Int32
    public var executablePath: String

    public init(pid: Int32, parentPID: Int32, executablePath: String) {
        self.pid = pid
        self.parentPID = parentPID
        self.executablePath = executablePath
    }
}

public struct ClaudeProcess: Equatable, Sendable {
    public var pid: Int32
    public var parentPID: Int32
    public var source: SessionSource
    public var command: String

    public init(pid: Int32, parentPID: Int32, source: SessionSource, command: String) {
        self.pid = pid
        self.parentPID = parentPID
        self.source = source
        self.command = command
    }
}

public struct ClaudeProcessSnapshot: Equatable, Sendable {
    public var scannedAt: Date
    public var processes: [ClaudeProcess]

    public init(scannedAt: Date = Date(), processes: [ClaudeProcess] = []) {
        self.scannedAt = scannedAt
        self.processes = processes
    }
}

public enum ClaudeProcessDetector {
    public enum DetectionError: Error, Equatable {
        case processListUnavailable(Int32)
        case unreadableProcessList
    }

    public static func scanCurrentProcesses(now: Date = Date()) throws -> ClaudeProcessSnapshot {
        let entries = try ProcessListEntry.current()
        return detect(entries: entries, now: now)
    }

    public static func detect(entries: [ProcessListEntry], now: Date = Date()) -> ClaudeProcessSnapshot {
        let entriesByPID = Dictionary(uniqueKeysWithValues: entries.map { ($0.pid, $0) })
        let processes = entries
            .filter(isClaudeCodeProcess)
            .map { entry in
                ClaudeProcess(
                    pid: entry.pid,
                    parentPID: entry.parentPID,
                    source: source(for: entry, entriesByPID: entriesByPID),
                    command: Redactor.safeSummary(entry.command)
                )
            }
            .sorted { lhs, rhs in
                lhs.pid < rhs.pid
            }

        return ClaudeProcessSnapshot(scannedAt: now, processes: processes)
    }

    public static func nearestClaudeAncestorPID(
        for processID: Int32,
        entries: [ProcessListEntry]
    ) -> Int32? {
        let entriesByPID = Dictionary(uniqueKeysWithValues: entries.map { ($0.pid, $0) })
        guard var parentPID = entriesByPID[processID]?.parentPID else {
            return nil
        }

        var visited = Set<Int32>()
        while let parent = entriesByPID[parentPID], !visited.contains(parent.pid) {
            visited.insert(parent.pid)
            if isClaudeCodeProcess(parent) {
                return parent.pid
            }
            parentPID = parent.parentPID
        }

        return nil
    }

    public static func nearestClaudeAncestorPID(
        for processID: Int32,
        inspect: (Int32) -> ProcessIdentity?
    ) -> Int32? {
        guard let process = inspect(processID) else {
            return nil
        }

        var parentPID = process.parentPID
        var visited = Set<Int32>()
        while parentPID > 0, !visited.contains(parentPID), let parent = inspect(parentPID) {
            visited.insert(parent.pid)
            let entry = ProcessListEntry(
                pid: parent.pid,
                parentPID: parent.parentPID,
                command: parent.executablePath
            )
            if isClaudeCodeProcess(entry) {
                return parent.pid
            }
            parentPID = parent.parentPID
        }

        return nil
    }

    public static func nearestClaudeAncestorPIDFromSystem(
        for processID: Int32 = ProcessInfo.processInfo.processIdentifier
    ) -> Int32? {
        nearestClaudeAncestorPID(for: processID) { pid in
            ProcessIdentity.current(pid: pid)
        }
    }

    private static func isClaudeCodeProcess(_ entry: ProcessListEntry) -> Bool {
        let command = entry.command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            return false
        }

        let lowercasedCommand = command.lowercased()
        if lowercasedCommand.contains("cc-sentinel") {
            return false
        }

        return commandHasExecutableNamed("claude", command: command)
            || lowercasedCommand.contains("@anthropic-ai/claude-code")
            || lowercasedCommand.contains("/claude-code/cli")
    }

    private static func source(
        for entry: ProcessListEntry,
        entriesByPID: [Int32: ProcessListEntry]
    ) -> SessionSource {
        var parentPID = entry.parentPID
        var visited = Set<Int32>()

        while let parent = entriesByPID[parentPID], !visited.contains(parent.pid) {
            visited.insert(parent.pid)
            if isVSCodeProcess(parent) {
                return .vscode
            }
            parentPID = parent.parentPID
        }

        return .cli
    }

    private static func isVSCodeProcess(_ entry: ProcessListEntry) -> Bool {
        let command = entry.command.lowercased()
        return command.contains("visual studio code.app")
            || command.contains("code helper")
            || command.contains("com.microsoft.vscode")
            || command.contains("/code.app/")
    }

    private static func commandHasExecutableNamed(_ name: String, command: String) -> Bool {
        command.split(whereSeparator: { $0.isWhitespace }).contains { token in
            let trimmed = String(token).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            let lastPathComponent = URL(fileURLWithPath: trimmed).lastPathComponent
            return lastPathComponent == name || trimmed == name
        }
    }
}

public extension ProcessIdentity {
    static func current(pid: Int32) -> ProcessIdentity? {
        #if canImport(Darwin)
        var pathBuffer = [CChar](repeating: 0, count: 4096)
        let pathLength = proc_pidpath(pid, &pathBuffer, UInt32(pathBuffer.count))
        guard pathLength > 0 else {
            return nil
        }

        var info = proc_bsdinfo()
        let infoLength = proc_pidinfo(
            pid,
            PROC_PIDTBSDINFO,
            0,
            &info,
            Int32(MemoryLayout<proc_bsdinfo>.stride)
        )
        guard infoLength == Int32(MemoryLayout<proc_bsdinfo>.stride) else {
            return nil
        }

        let executablePath = pathBuffer.withUnsafeBufferPointer { buffer in
            let endIndex = buffer.firstIndex(of: 0) ?? buffer.endIndex
            let bytes = buffer[..<endIndex].map { UInt8(bitPattern: $0) }
            return String(decoding: bytes, as: UTF8.self)
        }

        return ProcessIdentity(
            pid: pid,
            parentPID: Int32(info.pbi_ppid),
            executablePath: executablePath
        )
        #else
        return nil
        #endif
    }
}

public extension ProcessListEntry {
    static func current() throws -> [ProcessListEntry] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-axo", "pid=,ppid=,command="]

        let output = Pipe()
        let error = Pipe()
        process.standardOutput = output
        process.standardError = error

        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw ClaudeProcessDetector.DetectionError.processListUnavailable(process.terminationStatus)
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw ClaudeProcessDetector.DetectionError.unreadableProcessList
        }

        return parsePSOutput(text)
    }

    static func parsePSOutput(_ output: String) -> [ProcessListEntry] {
        output
            .split(separator: "\n", omittingEmptySubsequences: true)
            .compactMap { parsePSLine(String($0)) }
    }

    private static func parsePSLine(_ line: String) -> ProcessListEntry? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let fields = trimmed.split(
            maxSplits: 2,
            omittingEmptySubsequences: true
        ) { $0 == " " || $0 == "\t"
        }

        guard
            fields.count == 3,
            let pid = Int32(fields[0]),
            let parentPID = Int32(fields[1])
        else {
            return nil
        }

        return ProcessListEntry(pid: pid, parentPID: parentPID, command: String(fields[2]))
    }
}
