import Foundation

public enum CaptureError: Error, Equatable, Sendable {
    case xcodeMissing
    case notFound(query: String)
    case noDevice
    case noSimulator
    case notBooted
    case ambiguous(candidates: [String])
    case locked
    case developerDiskImage
    case unexpectedOutput(String)
    case failed(String)
}

extension CaptureError: LocalizedError {

    public var errorDescription: String? {
        switch self {
            case .xcodeMissing: "Xcode command-line tools not found (Xcode 27 or later is required)."
            case .notFound(let query): "No device matches '\(query)'."
            case .noDevice: "No ready (unlocked, reachable) iPhone or iPad found."
            case .noSimulator: "No iPhone or iPad simulator is running."
            case .notBooted: "The simulator is no longer running."
            case .ambiguous(let candidates): "Several devices are ready; choose one with --device: \(candidates.joined(separator: ", "))."
            case .locked: "The device is locked. Unlock it and try again."
            case .developerDiskImage: "The developer disk image could not be mounted on the device."
            case .unexpectedOutput(let detail): "Unexpected devicectl output: \(detail)"
            case .failed(let detail): "Capture failed: \(detail)"
        }
    }

    /// Classifies devicectl's or simctl's combined output; the CoreDevice/CoreSimulator messages are stable enough to match on.
    static func classify(output: String) -> CaptureError {
        switch output {
            case _ where output.contains("error 10003") || output.contains("still locked"): .locked
            case _ where output.contains("error 12040"): .developerDiskImage
            case _ where output.contains("current state: Shutdown") || output.contains("Invalid device") || output.contains("Timeout waiting for screen surfaces"): .notBooted
            default: .failed(summary(of: output))
        }
    }

    private static func summary(of output: String) -> String {
        let lines = output.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
        return lines.first { $0.hasPrefix("ERROR:") }?.dropFirst(6).trimmingCharacters(in: .whitespaces)
            ?? lines.last
            ?? "unknown error"
    }
}
