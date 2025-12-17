//
//  File.System.Link.Symbolic.swift
//  swift-file-system
//
//  Created by Coen ten Thije Boonkkamp on 17/12/2025.
//

extension File.System.Link {
    /// Symbolic link operations.
    public enum Symbolic {
        // TODO: Implementation
    }
}

extension File.System.Link.Symbolic {
    /// Error type for symbolic link operations.
    public enum Error: Swift.Error, Equatable, Sendable {
        case targetNotFound(File.Path)
        case permissionDenied(File.Path)
        case alreadyExists(File.Path)
        case linkFailed(errno: Int32, message: String)
    }
}
