// Only used by the Linux service harness; upload metadata is outside these tests.
public struct UTType {
    public init?(filenameExtension: String) { return nil }
    public var preferredMIMEType: String? { nil }
}
