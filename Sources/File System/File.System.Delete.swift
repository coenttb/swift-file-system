//
//  File.System.Delete.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System {
    /// Namespace for file deletion operations.
    public enum Delete {}
}

extension File.System.Delete {
    /// Options for delete operations.
    public struct Options: Sendable {
        /// Delete directories recursively.
        public var recursive: Bool

        public init(recursive: Bool = false) {
            self.recursive = recursive
        }
    }

    /// Error type for delete operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case isDirectory(File.Path)
        case directoryNotEmpty(File.Path)
        case deleteFailed(errno: Int32, message: String)
    }
}
