//
//  File.Directory.Walk.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.Directory {
    /// Recursive directory traversal.
    public enum Walk {
        // TODO: Implementation
    }
}

extension File.Directory.Walk {
    /// Options for directory traversal.
    public struct Options: Sendable {
        /// Maximum depth to traverse (nil for unlimited).
        public var maxDepth: Int?

        /// Whether to follow symbolic links.
        public var followSymlinks: Bool

        /// Whether to include hidden files.
        public var includeHidden: Bool

        public init(
            maxDepth: Int? = nil,
            followSymlinks: Bool = false,
            includeHidden: Bool = true
        ) {
            self.maxDepth = maxDepth
            self.followSymlinks = followSymlinks
            self.includeHidden = includeHidden
        }
    }

    /// Error type for directory walk operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case pathNotFound(File.Path)
        case permissionDenied(File.Path)
        case notADirectory(File.Path)
        case walkFailed(errno: Int32, message: String)
    }
}
