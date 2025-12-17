//
//  File.System.Create.Directory.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Create {
    /// Create new directories.
    public enum Directory {
        // TODO: Implementation
    }
}

extension File.System.Create.Directory {
    /// Options for directory creation.
    public struct Options: Sendable {
        /// Create intermediate directories as needed.
        public var createIntermediates: Bool

        /// Permissions for the new directory.
        public var permissions: File_System.File.System.Metadata.Permissions?

        public init(
            createIntermediates: Bool = false,
            permissions: File_System.File.System.Metadata.Permissions? = nil
        ) {
            self.createIntermediates = createIntermediates
            self.permissions = permissions
        }
    }

    /// Error type for directory creation operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case alreadyExists(File_System.File.Path)
        case permissionDenied(File_System.File.Path)
        case parentDirectoryNotFound(File_System.File.Path)
        case createFailed(errno: Int32, message: String)
    }
}
