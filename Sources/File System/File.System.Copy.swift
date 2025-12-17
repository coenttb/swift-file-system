//
//  File.System.Copy.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System {
    /// Namespace for file copy operations.
    public enum Copy {}
}

extension File.System.Copy {
    /// Options for copy operations.
    public struct Options: Sendable {
        /// Overwrite existing destination.
        public var overwrite: Bool

        /// Copy extended attributes.
        public var copyAttributes: Bool

        /// Follow symbolic links (copy target instead of link).
        public var followSymlinks: Bool

        public init(
            overwrite: Bool = false,
            copyAttributes: Bool = true,
            followSymlinks: Bool = true
        ) {
            self.overwrite = overwrite
            self.copyAttributes = copyAttributes
            self.followSymlinks = followSymlinks
        }
    }

    /// Error type for copy operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case sourceNotFound(File.Path)
        case destinationExists(File.Path)
        case permissionDenied(File.Path)
        case isDirectory(File.Path)
        case crossDevice(source: File.Path, destination: File.Path)
        case copyFailed(errno: Int32, message: String)
    }
}
