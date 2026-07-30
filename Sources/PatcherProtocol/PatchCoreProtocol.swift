import Foundation

public enum BottlePatchMode: String, Codable, CaseIterable, Sendable {
    case patchExisting
    case copyExisting
    case createNew
}

public struct PatchCoreRequest: Codable, Equatable, Sendable {
    public let sourceAppPath: String
    public let destinationAppPath: String
    public let bottlesRootPath: String
    public let bottleMode: BottlePatchMode
    public let sourceBottleName: String?
    public let destinationBottleName: String?

    public init(
        sourceAppPath: String,
        destinationAppPath: String,
        bottlesRootPath: String,
        bottleMode: BottlePatchMode,
        sourceBottleName: String?,
        destinationBottleName: String?
    ) {
        self.sourceAppPath = sourceAppPath
        self.destinationAppPath = destinationAppPath
        self.bottlesRootPath = bottlesRootPath
        self.bottleMode = bottleMode
        self.sourceBottleName = sourceBottleName
        self.destinationBottleName = destinationBottleName
    }
}

public struct RuntimePatchRequest: Codable, Equatable, Sendable {
    public let sourceAppPath: String
    public let destinationAppPath: String

    public init(sourceAppPath: String, destinationAppPath: String) {
        self.sourceAppPath = sourceAppPath
        self.destinationAppPath = destinationAppPath
    }
}

public struct PatchCoreEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case phase
        case progress
        case log
        case warning
        case completed
        case failed
    }

    public let kind: Kind
    public let phase: String?
    public let fraction: Double?
    public let message: String?
    public let outputAppPath: String?
    public let outputBottleName: String?

    public init(
        kind: Kind,
        phase: String? = nil,
        fraction: Double? = nil,
        message: String? = nil,
        outputAppPath: String? = nil,
        outputBottleName: String? = nil
    ) {
        self.kind = kind
        self.phase = phase
        self.fraction = fraction
        self.message = message
        self.outputAppPath = outputAppPath
        self.outputBottleName = outputBottleName
    }
}
