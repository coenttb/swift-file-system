//
//  File.System.Move.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System {
    /// Namespace for file move/rename operations.
    public enum Move {}
}

extension File.System.Move {
    /// Options for move operations.
    public struct Options: Sendable {
        /// Overwrite existing destination.
        public var overwrite: Bool

        public init(overwrite: Bool = false) {
            self.overwrite = overwrite
        }
    }

    /// Error type for move operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case sourceNotFound(File.Path)
        case destinationExists(File.Path)
        case permissionDenied(File.Path)
        case crossDevice(source: File.Path, destination: File.Path)
        case moveFailed(errno: Int32, message: String)
    }
}
