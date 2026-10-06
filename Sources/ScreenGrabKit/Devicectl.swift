import Foundation

/// Thin async wrapper around `xcrun devicectl`.
enum Devicectl {

    struct Output: Sendable {
        let status: Int32
        let text: String
    }

    static func run(_ arguments: [String]) async throws -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = ["devicectl"] + arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        process.standardInput = FileHandle.nullDevice

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    do {
                        try process.run()
                    } catch {
                        continuation.resume(throwing: CaptureError.devicectlMissing)
                        return
                    }
                    // Merged stdout/stderr: drain before waiting so a chatty child cannot fill the pipe and block.
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit()
                    continuation.resume(returning: Output(status: process.terminationStatus, text: String(decoding: data, as: UTF8.self)))
                }
            }
        } onCancel: {
            if process.isRunning { process.terminate() }
        }
    }
}
