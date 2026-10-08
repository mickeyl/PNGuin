import Foundation

/// Thin async wrapper around `xcrun <tool>`.
enum Xcrun {

    struct Output: Sendable {
        let status: Int32
        let text: String
    }

    /// Runs `tool`; `standardOutput` diverts stdout into a file for tools that print machine-readable data there
    /// (the merged `text` then only carries stderr). A `timeout` terminates the tool and throws.
    static func run(_ tool: String, _ arguments: [String], standardOutput: URL? = nil, timeout: Duration? = nil) async throws -> Output {
        guard let timeout else { return try await launch(tool, arguments, standardOutput: standardOutput) }

        return try await withThrowingTaskGroup(of: Output?.self) { group in
            group.addTask { try await launch(tool, arguments, standardOutput: standardOutput) }
            group.addTask {
                try await Task.sleep(for: timeout)
                return nil
            }
            defer { group.cancelAll() }
            guard let first = try await group.next(), let output = first else {
                throw CaptureError.failed("xcrun \(tool) did not finish within \(timeout)")
            }
            return output
        }
    }

    private static func launch(_ tool: String, _ arguments: [String], standardOutput: URL?) async throws -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = [tool] + arguments
        let pipe = Pipe()
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice
        if let standardOutput {
            FileManager.default.createFile(atPath: standardOutput.path, contents: nil)
            process.standardOutput = try FileHandle(forWritingTo: standardOutput)
        } else {
            process.standardOutput = pipe
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    do {
                        try process.run()
                    } catch {
                        continuation.resume(throwing: CaptureError.xcodeMissing)
                        return
                    }
                    // Drain before waiting so a chatty child cannot fill the pipe and block.
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    try? (process.standardOutput as? FileHandle)?.close()
                    continuation.resume(returning: Output(status: process.terminationStatus, text: String(decoding: data, as: UTF8.self)))
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}
