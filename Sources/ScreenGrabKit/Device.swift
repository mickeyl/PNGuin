import Foundation

public struct Device: Sendable, Equatable, Codable, Identifiable {

    public enum Kind: String, Sendable, Codable {
        case iPhone
        case iPad
    }

    /// CoreDevice lists every paired device regardless of reachability, so this is only known after probing.
    public enum Availability: String, Sendable, Codable {
        case unknown
        case ready
        case locked
        case unreachable
    }

    public let name: String
    public let udid: String
    public let kind: Kind
    public let osVersion: String?
    public var availability: Availability

    public var id: String { udid }
    public var isReady: Bool { availability == .ready }

    public init(name: String, udid: String, kind: Kind, osVersion: String?, availability: Availability = .unknown) {
        self.name = name
        self.udid = udid
        self.kind = kind
        self.osVersion = osVersion
        self.availability = availability
    }
}
